variable "shared" { type = "map" }
terraform { backend "s3" {} }
provider "aws" { region = "${var.shared["region"]}", version = "~> 1.15" }
provider "aws" { alias = "east", region = "us-east-1", version = "~> 1.15" }
data "aws_availability_zones" "all" {}

data "terraform_remote_state" "vpc" { backend = "s3", config = { key = "vpc/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "base" { backend = "s3", config = { key = "base/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "ret" { backend = "s3", config = { key = "ret/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "photomnemonic" { backend = "s3", config = { key = "photomnemonic/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }

data "aws_route53_zone" "drummon-zone" {
  name = "${var.drummon_domain}."
}

data "aws_acm_certificate" "drummon-cert-east" {
  provider = "aws.east"
  domain = "*.${var.drummon_domain}"
  statuses = ["ISSUED"]
  most_recent = true
}

resource "random_id" "bucket-identifier" {
  byte_length = 8
}

resource "aws_s3_bucket" "drummon-bucket" {
  bucket = "drummon-${var.shared["env"]}-${random_id.bucket-identifier.hex}"
  acl = "private"
}

resource "aws_iam_policy" "drummon-policy" {
  name = "${var.shared["env"]}-drummon-policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Action": "s3:GetObject",
        "Resource": "arn:aws:s3:::${aws_s3_bucket.drummon-bucket.id}/*"
    },
    {
        "Effect": "Allow",
        "Action": "s3:ListBucket",
        "Resource": "arn:aws:s3:::${aws_s3_bucket.drummon-bucket.id}"
    },
    {
        "Effect": "Allow",
        "Resource": "*",
        "Action": [
            "ec2:DescribeInstances",
            "ec2:CreateNetworkInterface",
            "ec2:AttachNetworkInterface",
            "ec2:DescribeNetworkInterfaces",
            "ec2:DeleteNetworkInterface",
            "autoscaling:CompleteLifecycleAction"
        ]
    },
    {
      "Action": ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
      "Resource": "arn:aws:logs:${var.shared["region"]}:${var.shared["account_id"]}:log-group:/aws/lambda/*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
  count = "${var.enabled}"
}

resource "aws_iam_role" "drummon-iam-role" {
  name = "${var.shared["env"]}-drummon"
  assume_role_policy = "${var.shared["lambda_role_policy"]}"
}

resource "aws_iam_role_policy_attachment" "drummon-role-attach" {
  role = "${aws_iam_role.drummon-iam-role.name}"
  policy_arn = "${aws_iam_policy.drummon-policy.arn}"
  count = "${var.enabled}"
}

resource "aws_security_group" "drummon" {
  name = "${var.shared["env"]}-drummon"
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
}
