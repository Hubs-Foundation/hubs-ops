variable "shared" { type = "map" }
terraform { backend "s3" {} }
provider "aws" { region = "${var.shared["region"]}", version = "~> 1.15" }
provider "aws" { alias = "east", region = "us-east-1", version = "~> 1.15" }
data "aws_availability_zones" "all" {}

data "terraform_remote_state" "vpc" { backend = "s3", config = { key = "vpc/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "base" { backend = "s3", config = { key = "base/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "ret" { backend = "s3", config = { key = "ret/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "photomnemonic" { backend = "s3", config = { key = "photomnemonic/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }

data "aws_route53_zone" "botomatic-zone" {
  name = "${var.botomatic_domain}."
}

resource "random_id" "bucket-identifier" {
  byte_length = 8
}

resource "aws_iam_policy" "botomatic-policy" {
  name = "${var.shared["env"]}-botomatic-policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
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
}

resource "aws_iam_role" "botomatic-iam-role" {
  name = "${var.shared["env"]}-botomatic"
  assume_role_policy = "${var.shared["lambda_role_policy"]}"
  count = "${var.enabled}"
}

resource "aws_iam_role_policy_attachment" "botomatic-role-attach" {
  role = "${aws_iam_role.botomatic-iam-role.name}"
  policy_arn = "${aws_iam_policy.botomatic-policy.arn}"
  count = "${var.enabled}"
}

resource "aws_security_group" "botomatic" {
  name = "${var.shared["env"]}-botomatic"
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

resource "aws_security_group" "botomatic-vpc-endpoint" {
  name = "${var.shared["env"]}-botomatic-vpc-endpoint"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"

  ingress {
    from_port = "443"
    to_port = "443"
    protocol = "tcp"
    security_groups = ["${data.terraform_remote_state.ret.ret_security_group_id}"]
  }
}

resource "aws_route53_record" "botomatic" {
  zone_id = "${data.aws_route53_zone.botomatic-zone.zone_id}"
  name    = "${var.botomatic_dns_prefix}${data.aws_route53_zone.botomatic-zone.name}"
  type    = "CNAME"
  ttl     = "300"
  records = ["${data.terraform_remote_state.photomnemonic.vpc-endpoint-dns}"]
}
