variable "shared" { type = "map" }
terraform { backend "s3" {} }
provider "aws" { region = "${var.shared["region"]}", version = "~> 2.19" }
provider "aws" { alias = "east", region = "us-east-1", version = "~> 2.19" }
data "aws_availability_zones" "all" {}

data "terraform_remote_state" "vpc" { backend = "s3", config = { key = "vpc/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "base" { backend = "s3", config = { key = "base/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "ret" { backend = "s3", config = { key = "ret/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "photomnemonic" { backend = "s3", config = { key = "photomnemonic/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }

data "aws_route53_zone" "speelycaptor-zone" {
  name = "${var.speelycaptor_domain}."
}

# You'll want to install this via 
# https://serverlessrepo.aws.amazon.com/applications/arn:aws:serverlessrepo:us-east-1:145266761615:applications~ffmpeg-lambda-layer
data "aws_lambda_layer_version" "ffmpeg" {
  layer_name = "ffmpeg"
}

resource "random_id" "bucket-identifier" {
  byte_length = 8
}

resource "aws_s3_bucket" "speelycaptor-bucket" {
  bucket = "speelycaptor-${var.shared["env"]}-${random_id.bucket-identifier.hex}"
  acl = "private"
}

resource "aws_s3_bucket" "speelycaptor-public-bucket" {
  bucket = "speelycaptor-${var.shared["env"]}-public-${random_id.bucket-identifier.hex}"
  acl = "private"
  count = "${var.public_enabled}"
}

resource "aws_s3_bucket" "speelycaptor-scratch-bucket" {
  bucket = "speelycaptor-${var.shared["env"]}-scratch-${random_id.bucket-identifier.hex}"
  acl = "private"

  lifecycle_rule {
    enabled = true

    expiration {
      days = 1
    }
  }
}

resource "aws_s3_bucket" "speelycaptor-public-scratch-bucket" {
  bucket = "speelycaptor-${var.shared["env"]}-public-scratch-${random_id.bucket-identifier.hex}"
  acl = "private"
  count = "${var.public_enabled}"

  lifecycle_rule {
    enabled = true

    expiration {
      days = 1
    }
  }
}

resource "aws_iam_policy" "speelycaptor-policy" {
  name = "${var.shared["env"]}-speelycaptor-policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Action": "s3:GetObject",
        "Resource": "arn:aws:s3:::${aws_s3_bucket.speelycaptor-bucket.id}/*"
    },
    {
        "Effect": "Allow",
        "Action": "s3:ListBucket",
        "Resource": "arn:aws:s3:::${aws_s3_bucket.speelycaptor-bucket.id}"
    },
    {
        "Effect": "Allow",
        "Action": "s3:GetObject",
        "Resource": "arn:aws:s3:::${aws_s3_bucket.speelycaptor-scratch-bucket.id}/*"
    },
    {
        "Effect": "Allow",
        "Action": "s3:PutObject",
        "Resource": "arn:aws:s3:::${aws_s3_bucket.speelycaptor-scratch-bucket.id}/*"
    },
    {
        "Effect": "Allow",
        "Action": "s3:PutObjectAcl",
        "Resource": "arn:aws:s3:::${aws_s3_bucket.speelycaptor-scratch-bucket.id}/*"
    },
    {
        "Effect": "Allow",
        "Action": "s3:ListBucket",
        "Resource": "arn:aws:s3:::${aws_s3_bucket.speelycaptor-scratch-bucket.id}"
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
}

resource "aws_iam_policy" "speelycaptor-public-policy" {
  name = "${var.shared["env"]}-speelycaptor-public-policy"
  count = "${var.public_enabled}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Action": "s3:GetObject",
        "Resource": "arn:aws:s3:::${aws_s3_bucket.speelycaptor-public-bucket.id}/*"
    },
    {
        "Effect": "Allow",
        "Action": "s3:ListBucket",
        "Resource": "arn:aws:s3:::${aws_s3_bucket.speelycaptor-public-bucket.id}"
    },
    {
        "Effect": "Allow",
        "Action": "s3:PutObject",
        "Resource": "arn:aws:s3:::${aws_s3_bucket.speelycaptor-public-scratch-bucket.id}/*"
    },
    {
        "Effect": "Allow",
        "Action": "s3:PutObjectAcl",
        "Resource": "arn:aws:s3:::${aws_s3_bucket.speelycaptor-public-scratch-bucket.id}/*"
    },
    {
        "Effect": "Allow",
        "Action": "s3:GetObject",
        "Resource": "arn:aws:s3:::${aws_s3_bucket.speelycaptor-public-scratch-bucket.id}/*"
    },
    {
        "Effect": "Allow",
        "Action": "s3:ListBucket",
        "Resource": "arn:aws:s3:::${aws_s3_bucket.speelycaptor-public-scratch-bucket.id}"
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
}

resource "aws_iam_role" "speelycaptor-iam-role" {
  name = "${var.shared["env"]}-speelycaptor"
  assume_role_policy = "${var.shared["lambda_role_policy"]}"
  count = "${var.enabled}"
}

resource "aws_iam_role" "speelycaptor-public-iam-role" {
  name = "${var.shared["env"]}-public-speelycaptor"
  assume_role_policy = "${var.shared["lambda_role_policy"]}"
  count = "${var.public_enabled}"
}

resource "aws_iam_role_policy_attachment" "speelycaptor-role-attach" {
  role = "${aws_iam_role.speelycaptor-iam-role.name}"
  policy_arn = "${aws_iam_policy.speelycaptor-policy.arn}"
  count = "${var.enabled}"
}

resource "aws_iam_role_policy_attachment" "speelycaptor-public-role-attach" {
  role = "${aws_iam_role.speelycaptor-public-iam-role.name}"
  policy_arn = "${aws_iam_policy.speelycaptor-public-policy.arn}"
  count = "${var.public_enabled}"
}

resource "aws_security_group" "speelycaptor" {
  name = "${var.shared["env"]}-speelycaptor"
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

resource "aws_route53_record" "speelycaptor" {
  zone_id = "${data.aws_route53_zone.speelycaptor-zone.zone_id}"
  name    = "${var.speelycaptor_dns_prefix}${data.aws_route53_zone.speelycaptor-zone.name}"
  type    = "CNAME"
  ttl     = "300"
  records = ["${data.terraform_remote_state.photomnemonic.vpc-endpoint-dns}"]
}
