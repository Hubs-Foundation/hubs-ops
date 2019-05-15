variable "shared" { type = "map" }
terraform { backend "s3" {} }
provider "aws" { region = "${var.shared["region"]}", version = "~> 1.15" }
provider "aws" { alias = "east", region = "us-east-1", version = "~> 1.15" }
data "aws_availability_zones" "all" {}

data "terraform_remote_state" "vpc" { backend = "s3", config = { key = "vpc/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "base" { backend = "s3", config = { key = "base/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "bastion" { backend = "s3", config = { key = "bastion/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "ret-db" { backend = "s3", config = { key = "ret-db/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }

data "aws_ami" "docker-base-ami" {
  most_recent = true
  owners = ["self"]

  filter {
    name = "name"
    values = ["docker-base-*"]
  }
}

resource "aws_security_group" "util" {
  name = "${var.shared["env"]}-util"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"

  egress {
    from_port = "80"
    to_port = "80"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = "443"
    to_port = "443"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH
  ingress {
    from_port = "22"
    to_port = "22"
    protocol = "tcp"
    security_groups = ["${data.terraform_remote_state.bastion.bastion_security_group_id}"]
  }

  # NTP
  egress {
    from_port = "123"
    to_port = "123"
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # PostgreSQL for DW migration
  egress {
    from_port = "5432"
    to_port = "5432"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "util" {
  name = "${var.shared["env"]}-util"
  assume_role_policy = "${var.shared["ec2_role_policy"]}"
}

resource "aws_iam_role_policy_attachment" "bastion-base-policy" {
  role = "${aws_iam_role.util.name}"
  policy_arn = "${data.terraform_remote_state.base.base_policy_arn}"
}

resource "aws_iam_instance_profile" "util" {
  name = "${var.shared["env"]}-util"
  role = "${aws_iam_role.util.id}"
}

resource "aws_launch_configuration" "util" {
  image_id = "${data.aws_ami.docker-base-ami.id}"
  instance_type = "${var.util_instance_type}"
  security_groups = [
    "${aws_security_group.util.id}",
    "${data.terraform_remote_state.ret-db.ret_db_consumer_security_group_id}"
  ]
  key_name = "${data.terraform_remote_state.base.mr_ssh_key_id}"
  iam_instance_profile = "${aws_iam_instance_profile.util.id}"
  associate_public_ip_address = false
  lifecycle { create_before_destroy = true }
  root_block_device { volume_size = 64 }
  user_data = <<EOF
#!/usr/bin/env bash
systemctl restart systemd-sysctl.service
EOF
}

resource "aws_autoscaling_group" "util" {
  name = "${var.shared["env"]}-util"
  launch_configuration = "${aws_launch_configuration.util.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  vpc_zone_identifier = ["${data.terraform_remote_state.vpc.private_subnet_ids}"]

  min_size = "1"
  max_size = "1"

  lifecycle { create_before_destroy = true }
  tag { key = "env", value = "${var.shared["env"]}", propagate_at_launch = true }
  tag { key = "host-type", value = "${var.shared["env"]}-util", propagate_at_launch = true }
}

