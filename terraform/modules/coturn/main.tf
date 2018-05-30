variable "shared" { type = "map" }
terraform { backend "s3" {} }
provider "aws" { region = "${var.shared["region"]}", version = "~> 1.15" }
provider "aws" { alias = "east", region = "us-east-1", version = "~> 1.15" }
data "aws_availability_zones" "all" {}

data "terraform_remote_state" "vpc" { backend = "s3", config = { key = "vpc/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "base" { backend = "s3", config = { key = "base/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "bastion" { backend = "s3", config = { key = "bastion/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "hab" { backend = "s3", config = { key = "hab/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }

data "aws_route53_zone" "reticulum-zone" {
  name = "${var.ret_domain}."
}

data "aws_acm_certificate" "ret-wildcard-cert" {
  domain = "*.${var.ret_domain}"
  statuses = ["ISSUED"]
}
data "aws_acm_certificate" "ret-wildcard-cert-east" {
  provider = "aws.east"
  domain = "*.${var.ret_domain}"
  statuses = ["ISSUED"]
}

data "aws_ami" "hab-base-ami" {
  most_recent = true
  owners = ["self"]

  filter {
    name = "name"
    values = ["hab-base-*"]
  }
}

resource "aws_security_group" "coturn" {
  name = "${var.shared["env"]}-coturn"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"
}

resource "aws_iam_role" "coturn" {
  name = "${var.shared["env"]}-coturn"
  assume_role_policy = "${var.shared["ec2_role_policy"]}"
}

resource "aws_iam_instance_profile" "coturn" {
  name = "${var.shared["env"]}-coturn"
  role = "${aws_iam_role.coturn.id}"
}

resource "aws_launch_configuration" "coturn" {
  image_id = "${data.aws_ami.hab-base-ami.id}"
  instance_type = "${var.coturn_instance_type}"
  security_groups = [
    "${aws_security_group.coturn.id}",
    "${data.terraform_remote_state.hab.hab_ring_security_group_id}",
  ]
  key_name = "${data.terraform_remote_state.base.mr_ssh_key_id}"
  iam_instance_profile = "${aws_iam_instance_profile.coturn.id}"
  associate_public_ip_address = false
  lifecycle { create_before_destroy = true }
  root_block_device { volume_size = 128 }
  user_data = <<EOF
#!/usr/bin/env bash
while ! [ -f /hab/sup/default/MEMBER_ID ] ; do sleep 1; done

sudo mkdir -p /hab/user/reticulum/config

sudo cat > /hab/user/reticulum/config/user.toml << EOTOML
[habitat]
ip = "$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
EOTOML

sudo /usr/bin/hab start mozillareality/coturn --strategy at-once --url https://bldr.habitat.sh --channel stable
sudo /usr/bin/hab start mozillareality/dd-agent --strategy at-once --url https://bldr.habitat.sh --channel stable --org mozillareality
EOF
}

resource "aws_autoscaling_group" "coturn" {
  name = "${var.shared["env"]}-coturn"
  launch_configuration = "${aws_launch_configuration.coturn.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  vpc_zone_identifier = ["${data.terraform_remote_state.vpc.private_subnet_ids}"]

  min_size = "${var.min_coturn_servers}"
  max_size = "${var.max_coturn_servers}"

  lifecycle { create_before_destroy = true }
  tag { key = "env", value = "${var.shared["env"]}", propagate_at_launch = true }
  tag { key = "host-type", value = "${var.shared["env"]}-coturn", propagate_at_launch = true }
  tag { key = "hab-ring", value = "${var.shared["env"]}", propagate_at_launch = true }
}
