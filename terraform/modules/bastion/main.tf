variable "shared" { type = "map" }
terraform { backend "s3" {} }
provider "aws" { region = "${var.shared["region"]}", version = "~> 0.1" }
data "aws_availability_zones" "all" {}

data "terraform_remote_state" "vpc" { backend = "s3", config = { key = "vpc/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "keys" { backend = "s3", config = { key = "keys/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }

resource "aws_security_group" "bastion" {
  name = "${var.shared["env"]}-bastion"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"

  # SSH
  egress {
    from_port = "0"
    to_port = "65535"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH
  ingress {
    from_port = "22"
    to_port = "22"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "bastion" {
  name = "${var.shared["env"]}-bastion"
  assume_role_policy = "${var.shared["ec2_role_policy"]}"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.shared["env"]}-bastion"
  role = "${aws_iam_role.bastion.id}"
}

resource "aws_launch_configuration" "bastion" {
  image_id = "${var.bastion_ami}"
  instance_type = "${var.bastion_instance_type}"
  security_groups = ["${aws_security_group.bastion.id}"]
  key_name = "${data.terraform_remote_state.keys.mr_ssh_key_id}"
  iam_instance_profile = "${aws_iam_instance_profile.bastion.id}"
  associate_public_ip_address = true
  lifecycle { create_before_destroy = true }
}

resource "aws_autoscaling_group" "bastion" {
  name = "${var.shared["env"]}-bastion"
  launch_configuration = "${aws_launch_configuration.bastion.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  vpc_zone_identifier = ["${data.terraform_remote_state.vpc.public_subnet_ids}"]

  min_size = "${var.min_bastion_servers}"
  max_size = "${var.max_bastion_servers}"

  lifecycle { create_before_destroy = true }
  tag { key = "Name", value = "${var.shared["env"]}-bastion", propagate_at_launch = false }
  tag { key = "env", value = "${var.shared["env"]}", propagate_at_launch = true }
  tag { key = "host-type", value = "${var.shared["env"]}-bastion", propagate_at_launch = true }
  tag { key = "hab-ring", value = "${var.shared["env"]}", propagate_at_launch = true }
}
