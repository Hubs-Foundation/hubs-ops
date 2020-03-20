# Provides shared, base resources

variable "shared" { type = "map" }
terraform { backend "s3" {} }
provider "aws" { region = "${var.shared["region"]}", version = "~> 1.15" }
provider "aws" { alias = "east", region = "us-east-1", version = "~> 1.15" }

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

# Assets bucket (public read)
resource "aws_s3_bucket" "assets-bucket" {
  bucket = "assets.reticulum-${var.shared["env"]}-${random_id.bucket-identifier.hex}"
  acl = "public-read"

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers = []
    max_age_seconds = 31536000
  }
}

# Asset bundles bucket (public read)
resource "aws_s3_bucket" "asset-bundles-bucket" {
  bucket = "asset-bundles.reticulum-${var.shared["env"]}-${random_id.bucket-identifier.hex}"
  acl = "public-read"

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers = ["ETag"]
    max_age_seconds = 31536000
  }
}

# Timecheck bucket (public read)
resource "aws_s3_bucket" "timecheck-bucket" {
  bucket = "timecheck.${var.shared["env"]}-${random_id.bucket-identifier.hex}"
  acl = "public-read"

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers = ["Date"]
    max_age_seconds = 31536000
  }

  website {
      index_document = "index.html"
      error_document = "error.html"
  }
}

resource "aws_s3_bucket_object" "timecheck-index" {
  bucket = "${aws_s3_bucket.timecheck-bucket.id}"
  key = "index.html"
  content = "<html></html>"
  acl = "public-read"
  cache_control = "no-cache"
}

# /link redirector (public read)
resource "aws_s3_bucket" "link-redirector-bucket" {
  bucket = "link-redirector.${var.shared["env"]}-${random_id.bucket-identifier.hex}"
  acl = "public-read"

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers = ["Date", "ETag"]
    max_age_seconds = 31536000
  }

  website {
      index_document = "index.html"
      error_document = "error.html"

      routing_rules = <<EOF
    [{
        "Redirect": {
            "ReplaceKeyPrefixWith": "link/",
            "Protocol": "https",
            "HostName": "${var.link_redirector_target_hostname}"
        }
    }]
    EOF
  }
}

resource "aws_s3_bucket_object" "redirector-index" {
  count = "${var.link_redirector_enabled}"
  bucket = "${aws_s3_bucket.link-redirector-bucket.id}"
  key = "index.html"
  content = "<html></html>"
  acl = "public-read"
  website_redirect = "${var.link_redirector_target}"
}

data "aws_acm_certificate" "link-redirector-cert-east" {
  provider = "aws.east"
  count = "${var.link_redirector_enabled}"
  domain = "${var.link_redirector_domains[0]}"
  statuses = ["ISSUED"]
  most_recent = true
}

data "aws_route53_zone" "link-redirector-zones" {
  count = "${length(var.link_redirector_domains)}"
  name = "${element(var.link_redirector_domains, count.index)}"
}

resource "aws_route53_record" "link-redirector-dns" {
  count = "${length(var.link_redirector_domains)}"
  zone_id = "${element(data.aws_route53_zone.link-redirector-zones.*.zone_id, count.index)}"
  name = "${element(data.aws_route53_zone.link-redirector-zones.*.name, count.index)}"
  type = "A"

  alias {
    name = "${aws_cloudfront_distribution.link-redirector.domain_name}"
    zone_id = "${aws_cloudfront_distribution.link-redirector.hosted_zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_cloudfront_distribution" "link-redirector" {
  enabled = true
  count = "${var.link_redirector_enabled}"

  origin {
    origin_id = "link-redirector-${var.shared["env"]}"
    domain_name = "${aws_s3_bucket.link-redirector-bucket.website_endpoint}"

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

  aliases = "${var.link_redirector_domains}"

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = "link-redirector-${var.shared["env"]}"

    forwarded_values {
      query_string = false
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
    acm_certificate_arn = "${data.aws_acm_certificate.link-redirector-cert-east.arn}"
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1"
  }
}

# / redirector (public read)
resource "aws_s3_bucket" "root-redirector-bucket" {
  bucket = "root-redirector.${var.shared["env"]}-${random_id.bucket-identifier.hex}"
  acl = "public-read"

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers = ["Date", "ETag"]
    max_age_seconds = 31536000
  }

  website {
      redirect_all_requests_to = "https://${var.root_redirector_target_hostname}"
  }
}

resource "aws_s3_bucket_object" "redirector-root-index" {
  count = "${var.root_redirector_enabled}"
  bucket = "${aws_s3_bucket.root-redirector-bucket.id}"
  key = "index.html"
  content = "<html></html>"
  acl = "public-read"
  website_redirect = "${var.root_redirector_target}"
}

data "aws_acm_certificate" "root-redirector-cert-east" {
  provider = "aws.east"
  count = "${var.root_redirector_enabled}"
  domain = "${var.root_redirector_domains[0]}"
  statuses = ["ISSUED"]
  most_recent = true
}

data "aws_route53_zone" "root-redirector-zones" {
  count = "${length(var.root_redirector_domains)}"
  name = "${element(var.root_redirector_domains, count.index)}"
}

resource "aws_route53_record" "root-redirector-dns" {
  count = "${length(var.root_redirector_domains)}"
  zone_id = "${element(data.aws_route53_zone.root-redirector-zones.*.zone_id, count.index)}"
  name = "${element(data.aws_route53_zone.root-redirector-zones.*.name, count.index)}"
  type = "A"

  alias {
    name = "${aws_cloudfront_distribution.root-redirector.domain_name}"
    zone_id = "${aws_cloudfront_distribution.root-redirector.hosted_zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_cloudfront_distribution" "root-redirector" {
  enabled = true
  count = "${var.root_redirector_enabled}"

  origin {
    origin_id = "root-redirector-${var.shared["env"]}"
    domain_name = "${aws_s3_bucket.root-redirector-bucket.website_endpoint}"

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

  aliases = "${var.root_redirector_domains}"

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = "root-redirector-${var.shared["env"]}"

    forwarded_values {
      query_string = false
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
    acm_certificate_arn = "${data.aws_acm_certificate.root-redirector-cert-east.arn}"
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1"
  }
}
resource "aws_s3_bucket" "stack-create-redirector-bucket" {
  bucket = "stack-create-redirector.${var.shared["env"]}-${random_id.bucket-identifier.hex}"
  acl = "public-read"

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers = ["Date", "ETag"]
    max_age_seconds = 31536000
  }

  website {
      index_document = "index.html"
      error_document = "error.html"

      routing_rules = <<EOF
    [{
        "Redirect": {
            "ReplaceKeyPrefixWith": "cloud",
            "Protocol": "https",
            "HostName": "hubs.mozilla.com"
        }
    }]
    EOF
  }
}

resource "aws_s3_bucket_object" "redirector-stack-create-index" {
  count = "${var.stack_create_redirector_enabled}"
  bucket = "${aws_s3_bucket.stack-create-redirector-bucket.id}"
  key = "index.html"
  content = "<html></html>"
  acl = "public-read"
  website_redirect = "${var.stack_create_redirector_target}"
}

data "aws_acm_certificate" "stack-create-redirector-cert-east" {
  provider = "aws.east"
  count = "${var.stack_create_redirector_enabled}"
  domain = "${var.stack_create_redirector_domains[0]}"
  statuses = ["ISSUED"]
  most_recent = true
}

data "aws_route53_zone" "stack-create-redirector-zones" {
  count = "${length(var.stack_create_redirector_domains)}"
  name = "${element(var.stack_create_redirector_domains, count.index)}"
}

resource "aws_route53_record" "stack-create-redirector-dns" {
  count = "${length(var.stack_create_redirector_domains)}"
  zone_id = "${element(data.aws_route53_zone.stack-create-redirector-zones.*.zone_id, count.index)}"
  name = "${element(data.aws_route53_zone.stack-create-redirector-zones.*.name, count.index)}"
  type = "A"

  alias {
    name = "${aws_cloudfront_distribution.stack-create-redirector.domain_name}"
    zone_id = "${aws_cloudfront_distribution.stack-create-redirector.hosted_zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_cloudfront_distribution" "stack-create-redirector" {
  enabled = true
  count = "${var.stack_create_redirector_enabled}"

  origin {
    origin_id = "stack-create-redirector-${var.shared["env"]}"
    domain_name = "${aws_s3_bucket.stack-create-redirector-bucket.website_endpoint}"

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

  aliases = "${var.stack_create_redirector_domains}"

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = "stack-create-redirector-${var.shared["env"]}"

    forwarded_values {
      query_string = false
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
    acm_certificate_arn = "${data.aws_acm_certificate.stack-create-redirector-cert-east.arn}"
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1"
  }
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
  function_name    = "${var.shared["env"]}-cloudfront-sg-update"
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

# Docs bucket (public read)
resource "aws_s3_bucket" "docs-bucket" {
  bucket = "docs.reticulum-${var.shared["env"]}-${random_id.bucket-identifier.hex}"
  acl = "public-read"

  website {
      index_document = "index.html"
      error_document = "error.html"
  }
}
