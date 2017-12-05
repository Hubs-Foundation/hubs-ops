# Provides shared, base resources

variable "shared" { type = "map" }
terraform { backend "s3" {} }
provider "aws" { region = "${var.shared["region"]}", version = "~> 0.1" }
provider "aws" { alias = "east", region = "us-east-1", version = "~> 0.1" }

data "terraform_remote_state" "vpc" { backend = "s3", config = { key = "vpc/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }

resource "aws_key_pair" "mr-ssh-key" {
  key_name = "${var.shared["env"]}-mr-ssh-key"
  public_key = "${var.ssh_public_key}"
}

# Shared base policy for all nodes
resource "aws_iam_policy" "base-policy" {
  name = "${var.shared["env"]}-base-policy"
  policy = "${var.shared["base_policy"]}"
}

resource "random_id" "bucket-identifier" {
  byte_length = 8
}

# Logs bucket
resource "aws_s3_bucket" "logs-bucket" {
  bucket = "logs.reticulum-${var.shared["env"]}-${random_id.bucket-identifier.hex}"
  acl = "private"
}

# Backups bucket
resource "aws_s3_bucket" "backups-bucket" {
  bucket = "backups.reticulum-${var.shared["env"]}-${random_id.bucket-identifier.hex}"
  acl = "private"

  lifecycle_rule {
    id = "jenkins-backups"
    enabled = true
    prefix = "ci/jenkins-backups/*"

    transition {
      days = 7
      storage_class = "GLACIER"
    }

    expiration {
      days = 90
    }
  }
}

# Builds bucket (public read)
resource "aws_s3_bucket" "builds-bucket" {
  bucket = "builds.reticulum-${var.shared["env"]}-${random_id.bucket-identifier.hex}"
  acl = "public-read"
}

resource "aws_security_group" "cloudfront-http" {
  name = "${var.shared["env"]}-cloudfront-http"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"

  tags {
    Name = "cloudfront"
    AutoUpdate = "true"
    Protocol = "http"
  }
}

resource "aws_security_group" "cloudfront-https" {
  name = "${var.shared["env"]}-cloudfront-https"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"

  tags {
    Name = "cloudfront"
    AutoUpdate = "true"
    Protocol = "https"
  }
}

resource "aws_iam_role" "cloudfront-sg-update-lambda-iam-role" {
  name = "${var.shared["env"]}-cloudfront-sg-update"
  assume_role_policy = "${var.shared["lambda_role_policy"]}"
}

resource "aws_iam_role_policy_attachment" "lambda-sg-update-policy" {
  role = "${aws_iam_role.cloudfront-sg-update-lambda-iam-role.name}"
  policy_arn = "${aws_iam_policy.sg-update-policy.arn}"
}

resource "aws_iam_policy" "sg-update-policy" {
  name = "${var.shared["env"]}-sg-update-policy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeSecurityGroups",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

# NOTE: The AWS Lambda function for updating CloudFront security groups
# is hardcoded to us-west-1 region, you'll need to update the zip file's main.py
# if you are using a different region.
#
# See: https://aws.amazon.com/blogs/security/how-to-automatically-update-your-security-groups-for-amazon-cloudfront-and-aws-waf-by-using-aws-lambda/
resource "aws_lambda_function" "cloudfront-sg-update" {
  provider = "aws.east"
  filename         = "cloudfront-sg-update.zip"
  function_name    = "cloudfront-sg-update"
  role             = "${aws_iam_role.cloudfront-sg-update-lambda-iam-role.arn}"
  handler          = "main.lambda_handler"
  source_code_hash = "${base64sha256(file("cloudfront-sg-update.zip"))}"
  runtime          = "python2.7"
  timeout = 15
}

resource "aws_sns_topic_subscription" "cloudfront-sg-update" {
  provider = "aws.east"
  topic_arn = "arn:aws:sns:us-east-1:806199016981:AmazonIpSpaceChanged"
  protocol  = "lambda"
  endpoint  = "${aws_lambda_function.cloudfront-sg-update.arn}"
}

resource "aws_kms_key" "lambda-kms-key" {
  provider = "aws.east"
  description = "Key for AWS Lambda secrets"
}
