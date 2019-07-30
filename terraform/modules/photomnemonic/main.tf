variable "shared" { type = "map" }
terraform { backend "s3" {} }
provider "aws" { region = "${var.shared["region"]}", version = "~> 1.15" }
provider "aws" { alias = "east", region = "us-east-1", version = "~> 1.15" }
data "aws_availability_zones" "all" {}

data "terraform_remote_state" "vpc" { backend = "s3", config = { key = "vpc/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "base" { backend = "s3", config = { key = "base/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "ret" { backend = "s3", config = { key = "ret/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }

data "aws_route53_zone" "photomnemonic-zone" {
  name = "${var.photomnemonic_domain}."
}

data "aws_acm_certificate" "photomnemonic-utils-cert-east" {
  provider = "aws.east"
  domain = "*.${var.photomnemonic_domain}"
  statuses = ["ISSUED"]
  most_recent = true
}

resource "random_id" "bucket-identifier" {
  byte_length = 8
}

resource "aws_s3_bucket" "photomnemonic-bucket" {
  bucket = "photomnemonic-${var.shared["env"]}-${random_id.bucket-identifier.hex}"
  acl = "private"
}

resource "aws_s3_bucket" "photomnemonic-utils" {
  bucket = "photomnemonic-utils-${var.shared["env"]}-${random_id.bucket-identifier.hex}"
  acl = "public-read"

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers = ["Date", "ETag"]
    max_age_seconds = 31536000
  }
}

resource "aws_s3_bucket_object" "photomnemonic-pdf" {
  bucket = "${aws_s3_bucket.photomnemonic-utils.id}"
  key = "pdf.html"
  source = "pdf.html"
  acl = "public-read"
}

resource "aws_cloudfront_distribution" "photomnemonic-utils" {
  enabled = "true"

  origin {
    origin_id = "photomnemonic-utils-${var.shared["env"]}"
    domain_name = "${aws_s3_bucket.photomnemonic-utils.bucket_domain_name}"

    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_ssl_protocols = ["SSLv3", "TLSv1", "TLSv1.1", "TLSv1.2"]
      origin_protocol_policy = "http-only"
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  aliases = ["${var.photomnemonic_utils_dns_prefix}${var.photomnemonic_domain}"]

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = "photomnemonic-utils-${var.shared["env"]}"

    forwarded_values {
      query_string = true
      headers = []
      cookies { forward = "none" }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl = 86400
    default_ttl = 86400
    max_ttl = 86400
  }

  price_class = "PriceClass_All"

  viewer_certificate {
    acm_certificate_arn = "${data.aws_acm_certificate.photomnemonic-utils-cert-east.arn}"
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1"
  }
}

resource "aws_route53_record" "photomnemonic-utils-dns" {
  zone_id = "${data.aws_route53_zone.photomnemonic-zone.zone_id}"
  name= "${var.photomnemonic_utils_dns_prefix}${data.aws_route53_zone.photomnemonic-zone.name}"
  type = "A"

  alias {
    name = "${aws_cloudfront_distribution.photomnemonic-utils.domain_name}"
    zone_id = "${aws_cloudfront_distribution.photomnemonic-utils.hosted_zone_id}"
    evaluate_target_health = false
  }
}


resource "aws_iam_policy" "photomnemonic-policy" {
  name = "${var.shared["env"]}-photomnemonic-policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Action": "s3:GetObject",
        "Resource": "arn:aws:s3:::${aws_s3_bucket.photomnemonic-bucket.id}/*"
    },
    {
        "Effect": "Allow",
        "Action": "s3:ListBucket",
        "Resource": "arn:aws:s3:::${aws_s3_bucket.photomnemonic-bucket.id}"
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

resource "aws_iam_role" "photomnemonic-iam-role" {
  name = "${var.shared["env"]}-photomnemonic"
  assume_role_policy = "${var.shared["lambda_role_policy"]}"
  count = "${var.enabled}"
}

resource "aws_iam_role_policy_attachment" "photomnemonic-role-attach" {
  role = "${aws_iam_role.photomnemonic-iam-role.name}"
  policy_arn = "${aws_iam_policy.photomnemonic-policy.arn}"
  count = "${var.enabled}"
}

resource "aws_security_group" "photomnemonic" {
  name = "${var.shared["env"]}-photomnemonic"
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

resource "aws_security_group" "photomnemonic-vpc-endpoint" {
  name = "${var.shared["env"]}-photomnemonic-vpc-endpoint"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"

  ingress {
    from_port = "443"
    to_port = "443"
    protocol = "tcp"
    security_groups = ["${data.terraform_remote_state.ret.ret_security_group_id}"]
  }
}

resource "aws_vpc_endpoint" "photomnemonic" {
  vpc_id            = "${data.terraform_remote_state.vpc.vpc_id}"
  vpc_endpoint_type = "Interface"
  service_name      = "com.amazonaws.${var.shared["region"]}.execute-api"
  vpc_endpoint_type = "Interface"
  subnet_ids = ["${data.terraform_remote_state.vpc.private_subnet_ids}"]

  security_group_ids = [
    "${aws_security_group.photomnemonic-vpc-endpoint.id}",
  ]

  private_dns_enabled = true
}

resource "aws_route53_record" "photomnemonic" {
  zone_id = "${data.aws_route53_zone.photomnemonic-zone.zone_id}"
  name    = "${var.photomnemonic_dns_prefix}${data.aws_route53_zone.photomnemonic-zone.name}"
  type    = "CNAME"
  ttl     = "300"
  records = ["${lookup(aws_vpc_endpoint.photomnemonic.dns_entry[0], "dns_name")}"]
}
