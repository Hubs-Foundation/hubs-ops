variable "shared" { type = "map" }
terraform { backend "s3" {} }
provider "aws" { region = "${var.shared["region"]}", version = "~> 1.15" }
provider "aws" { alias = "east", region = "us-east-1", version = "~> 1.15" }
data "aws_availability_zones" "all" {}

data "terraform_remote_state" "vpc" { backend = "s3", config = { key = "vpc/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "base" { backend = "s3", config = { key = "base/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "bastion" { backend = "s3", config = { key = "bastion/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "hab" { backend = "s3", config = { key = "hab/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }

data "aws_route53_zone" "farspark-zone" {
  name = "${var.farspark_domain}."
}

data "aws_acm_certificate" "farspark-alb-listener-cert" {
  domain = "*.${var.farspark_domain}"
  statuses = ["ISSUED"]
  most_recent = true
}

data "aws_acm_certificate" "farspark-alb-listener-cert-east" {
  provider = "aws.east"
  domain = "*.${var.farspark_domain}"
  statuses = ["ISSUED"]
  most_recent = true
}

data "aws_ami" "hab-base-ami" {
  most_recent = true
  owners = ["self"]

  filter {
    name = "name"
    values = ["hab-base-*"]
  }
}

resource "aws_security_group" "farspark-alb" {
  name = "${var.shared["env"]}-farspark-alb"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"
}

resource "aws_security_group_rule" "farspark-alb-egress" {
  type = "egress"
  from_port = "${var.farspark_http_port}"
  to_port = "${var.farspark_http_port}"
  protocol = "tcp"
  security_group_id = "${aws_security_group.farspark-alb.id}"
  source_security_group_id = "${aws_security_group.farspark.id}"
}

resource "aws_alb" "farspark-alb" {
  name = "${var.shared["env"]}-farspark-alb"

  security_groups = [
    "${aws_security_group.farspark-alb.id}",
    "${data.terraform_remote_state.base.cloudfront_http_security_group_id}",
    "${data.terraform_remote_state.base.cloudfront_https_security_group_id}"
  ]

  subnets = ["${data.terraform_remote_state.vpc.public_subnet_ids}"]

  lifecycle { create_before_destroy = true }
}

resource "aws_alb_target_group" "farspark-alb-group-http" {
  name = "${var.shared["env"]}-farspark-alb-group-http"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"
  port = "${var.farspark_http_port}"
  protocol = "HTTP"
  deregistration_delay = 0

  health_check {
    path = "/health"
    healthy_threshold = 2
    unhealthy_threshold = 2
    interval = 10
    timeout = 5
  }
}

resource "aws_alb_listener" "farspark-ssl-alb-listener" {
  load_balancer_arn = "${aws_alb.farspark-alb.arn}"
  port = 443

  protocol = "HTTPS"
  ssl_policy = "ELBSecurityPolicy-2015-05"

  certificate_arn = "${data.aws_acm_certificate.farspark-alb-listener-cert.arn}"

  default_action {
    target_group_arn = "${aws_alb_target_group.farspark-alb-group-http.arn}"
    type = "forward"
  }
}

resource "aws_security_group" "farspark" {
  name = "${var.shared["env"]}-farspark"
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

  # Farspark HTTP
  ingress {
    from_port = "${var.farspark_http_port}"
    to_port = "${var.farspark_http_port}"
    protocol = "tcp"
    security_groups = ["${aws_security_group.farspark-alb.id}"]
  }

  # SSH
  ingress {
    from_port = "22"
    to_port = "22"
    protocol = "tcp"
    security_groups = ["${data.terraform_remote_state.bastion.bastion_security_group_id}"]
  }

  # NTP
  egress {
    from_port = "123"
    to_port = "123"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "farspark" {
  name = "${var.shared["env"]}-farspark"
  assume_role_policy = "${var.shared["ec2_role_policy"]}"
}

resource "aws_iam_role_policy_attachment" "bastion-base-policy" {
  role = "${aws_iam_role.farspark.name}"
  policy_arn = "${data.terraform_remote_state.base.base_policy_arn}"
}

resource "aws_iam_instance_profile" "farspark" {
  name = "${var.shared["env"]}-farspark"
  role = "${aws_iam_role.farspark.id}"
}

resource "aws_launch_configuration" "farspark" {
  image_id = "${data.aws_ami.hab-base-ami.id}"
  instance_type = "${var.farspark_instance_type}"
  security_groups = [
    "${aws_security_group.farspark.id}",
    "${data.terraform_remote_state.hab.hab_ring_security_group_id}",
  ]
  key_name = "${data.terraform_remote_state.base.mr_ssh_key_id}"
  iam_instance_profile = "${aws_iam_instance_profile.farspark.id}"
  associate_public_ip_address = false
  lifecycle { create_before_destroy = true }
  root_block_device { volume_size = 64 }
  user_data = <<EOF
#!/usr/bin/env bash
while ! nc -z localhost 9632 ; do sleep 1; done

sudo /usr/bin/hab svc load mozillareality/farspark --strategy ${var.farspark_restart_strategy} --url https://bldr.habitat.sh --channel ${var.farspark_channel}
sudo /usr/bin/hab svc load mozillareality/dd-agent --strategy at-once --url https://bldr.habitat.sh --channel stable
EOF
}

resource "aws_autoscaling_group" "farspark" {
  name = "${var.shared["env"]}-farspark"
  launch_configuration = "${aws_launch_configuration.farspark.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  vpc_zone_identifier = ["${data.terraform_remote_state.vpc.private_subnet_ids}"]

  min_size = "${var.min_farspark_servers}"
  max_size = "${var.max_farspark_servers}"

  target_group_arns = ["${aws_alb_target_group.farspark-alb-group-http.arn}"]

  lifecycle { create_before_destroy = true }
  tag { key = "env", value = "${var.shared["env"]}", propagate_at_launch = true }
  tag { key = "host-type", value = "${var.shared["env"]}-farspark", propagate_at_launch = true }
  tag { key = "hab-ring", value = "${var.shared["env"]}", propagate_at_launch = true }
}

resource "aws_cloudfront_distribution" "farspark-cdn" {
  enabled = true

  origin {
    origin_id = "farspark-${var.shared["env"]}"
    domain_name = "${var.shared["env"]}-farspark-alb.${var.farspark_domain}"

    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_ssl_protocols = ["SSLv3", "TLSv1", "TLSv1.1", "TLSv1.2"]
      origin_protocol_policy = "https-only"
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  aliases = ["${var.farspark_dns_prefix}${var.farspark_domain}"]

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = "farspark-${var.shared["env"]}"

    forwarded_values {
      query_string = true
      headers = ["Origin", "Content-Type"]
      cookies { forward = "none" }
    }

    viewer_protocol_policy = "https-only"
    min_ttl = 0
    default_ttl = 3600
    max_ttl = 3600
  }

  custom_error_response {
    error_code = 403
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code = 404
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code = 500
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code = 502
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code = 503
    error_caching_min_ttl = 0
  }

  price_class = "PriceClass_All"

  viewer_certificate {
    acm_certificate_arn = "${data.aws_acm_certificate.farspark-alb-listener-cert-east.arn}"
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1"
  }
}

resource "aws_route53_record" "farspark-alb-dns" {
  zone_id = "${data.aws_route53_zone.farspark-zone.zone_id}"
  name = "${var.shared["env"]}-farspark-alb.${data.aws_route53_zone.farspark-zone.name}"
  type = "A"

  alias {
    name = "${aws_alb.farspark-alb.dns_name}"
    zone_id = "${aws_alb.farspark-alb.zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "farspark-dns" {
  zone_id = "${data.aws_route53_zone.farspark-zone.zone_id}"
  name = "${var.farspark_dns_prefix}${data.aws_route53_zone.farspark-zone.name}"
  type = "A"

  alias {
    name = "${aws_cloudfront_distribution.farspark-cdn.domain_name}"
    zone_id = "${aws_cloudfront_distribution.farspark-cdn.hosted_zone_id}"
    evaluate_target_health = false
  }
}
