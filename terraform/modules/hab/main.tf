variable "shared" { type = "map" }
terraform { backend "s3" {} }
provider "aws" { region = "${var.shared["region"]}", version = "~> 0.1" }
data "aws_availability_zones" "all" {}

data "terraform_remote_state" "vpc" { backend = "s3", config = { key = "vpc/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "base" { backend = "s3", config = { key = "base/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "bastion" { backend = "s3", config = { key = "bastion/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }

data "aws_ami" "hab-base-ami" {
  most_recent = true
  owners = ["self"]

  filter {
    name = "name"
    values = ["hab-base-*"]
  }
}

resource "aws_security_group" "hab" {
  name = "${var.shared["env"]}-hab"
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

  # Papertrail
  egress {
    from_port = "28666"
    to_port = "28666"
    protocol = "tcp"
    cidr_blocks = ["169.46.82.160/27"]
  }

  # NTP
  egress {
    from_port = "123"
    to_port = "123"
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
}

resource "aws_security_group" "hab-ring" {
  name = "${var.shared["env"]}-hab-ring"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"

  ingress {
    from_port = "9631"
    to_port = "9631"
    protocol = "tcp"
    self = true
  }

  egress {
    from_port = "9631"
    to_port = "9631"
    protocol = "tcp"
    self = true
  }

  ingress {
    from_port = "9631"
    to_port = "9631"
    protocol = "tcp"
    security_groups = ["${data.terraform_remote_state.bastion.bastion_security_group_id}"]
  }

  ingress {
    from_port = "9638"
    to_port = "9638"
    protocol = "tcp"
    self = true
  }

  egress {
    from_port = "9638"
    to_port = "9638"
    protocol = "tcp"
    self = true
  }

  ingress {
    from_port = "9638"
    to_port = "9638"
    protocol = "udp"
    self = true
  }

  egress {
    from_port = "9638"
    to_port = "9638"
    protocol = "udp"
    self = true
  }
}

resource "aws_iam_role" "hab" {
  name = "${var.shared["env"]}-hab"
  assume_role_policy = "${var.shared["ec2_role_policy"]}"
}

resource "aws_iam_role_policy_attachment" "hab-base-policy" {
  role = "${aws_iam_role.hab.name}"
  policy_arn = "${data.terraform_remote_state.base.base_policy_arn}"
}

resource "aws_iam_instance_profile" "hab" {
  name = "${var.shared["env"]}-hab"
  role = "${aws_iam_role.hab.id}"
}

resource "aws_launch_configuration" "hab" {
  image_id = "${data.aws_ami.hab-base-ami.id}"
  instance_type = "${var.hab_instance_type}"
  security_groups = ["${aws_security_group.hab.id}", "${aws_security_group.hab-ring.id}"]
  key_name = "${data.terraform_remote_state.base.mr_ssh_key_id}"
  iam_instance_profile = "${aws_iam_instance_profile.hab.id}"
  associate_public_ip_address = false
  lifecycle { create_before_destroy = true }

  user_data = <<EOF
#!/usr/bin/env bash
while ! nc -z localhost 9632 ; do sleep 1; done
systemctl restart systemd-sysctl.service
sudo /usr/bin/hab svc load mozillareality/dd-agent --strategy at-once --url https://bldr.habitat.sh --channel stable
EOF
}

resource "aws_autoscaling_group" "hab" {
  name = "${var.shared["env"]}-hab"
  launch_configuration = "${aws_launch_configuration.hab.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  vpc_zone_identifier = ["${data.terraform_remote_state.vpc.private_subnet_ids}"]

  min_size = "${var.min_hab_servers}"
  max_size = "${var.max_hab_servers}"

  lifecycle { create_before_destroy = true }
  tag { key = "env", value = "${var.shared["env"]}", propagate_at_launch = true }
  tag { key = "host-type", value = "${var.shared["env"]}-hab", propagate_at_launch = true }
  tag { key = "hab-ring", value = "${var.shared["env"]}", propagate_at_launch = true }
}
