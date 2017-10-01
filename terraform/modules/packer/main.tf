
variable "shared" { type = "map" }
terraform { backend "s3" {} }
provider "aws" { region = "${var.shared["region"]}", version = "~> 0.1" }

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    key = "vpc/terraform.tfstate"
    bucket = "${var.shared["state_bucket"]}"
    region = "${var.shared["region"]}"
    dynamodb_table = "${var.shared["dynamodb_table"]}"
    encrypt = "true"
  }
}

resource "aws_iam_role" "packer" {
  name = "${var.shared["env"]}-packer"
  assume_role_policy = "${var.shared["ec2_role_policy"]}"
}

resource "aws_iam_instance_profile" "packer" {
  name = "${var.shared["env"]}-packer"
  role = "${aws_iam_role.packer.id}"
}

resource "aws_security_group" "packer" {
  name = "${var.shared["env"]}-packer"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"

  # SSH
  ingress {
    from_port = "22"
    to_port = "22"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
}
