variable "shared" { type = "map" }
terraform { backend "s3" {} }
provider "aws" { region = "${var.shared["region"]}", version = "~> 1.15" }
provider "aws" { alias = "east", region = "us-east-1", version = "~> 1.15" }
data "aws_availability_zones" "all" {}

data "terraform_remote_state" "vpc" { backend = "s3", config = { key = "vpc/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "base" { backend = "s3", config = { key = "base/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "bastion" { backend = "s3", config = { key = "bastion/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "hab" { backend = "s3", config = { key = "hab/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "base-prod" { backend = "s3", config = { key = "base/terraform.tfstate", bucket = "mr-prod.terraform", region = "us-west-1", dynamodb_table = "mr-prod-terraform-lock", encrypt = "true" } }

data "aws_route53_zone" "reticulum-zone" {
  name = "${var.ret_domain}."
}

data "aws_acm_certificate" "ret-wildcard-cert" {
  domain = "*.${var.ret_domain}"
  statuses = ["ISSUED"]
  most_recent = true
}
data "aws_acm_certificate" "ret-wildcard-cert-east" {
  provider = "aws.east"
  domain = "*.${var.ret_domain}"
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

resource "aws_security_group" "ci" {
  name = "${var.shared["env"]}-ci"

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

  egress {
    from_port = "53"
    to_port = "53"
    protocol = "udp"
    cidr_blocks = ["8.8.8.8/32", "4.4.4.4/32"]
  }

  # NTP
  egress {
    from_port = "123"
    to_port = "123"
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Git (for fetching deps)
  egress {
    from_port = "9418"
    to_port = "9418"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Jenkins
  ingress {
    from_port = "8080"
    to_port = "8080"
    protocol = "tcp"
    security_groups = ["${data.terraform_remote_state.bastion.bastion_security_group_id}"]
  }

  # SSH
  ingress {
    from_port = "22"
    to_port = "22"
    protocol = "tcp"
    security_groups = ["${data.terraform_remote_state.bastion.bastion_security_group_id}"]
  }

  # Webhook + Job hook ALB
  ingress {
    from_port = "8080"
    to_port = "8080"
    protocol = "tcp"
    security_groups = ["${aws_security_group.ci-alb.id}"]
  }
}

resource "aws_iam_role" "ci" {
  name = "${var.shared["env"]}-ci"
  count = "${var.enabled}"

  assume_role_policy = "${var.shared["ec2_role_policy"]}"
}

resource "aws_iam_role_policy_attachment" "ci-base-policy" {
  role = "${aws_iam_role.ci.name}"
  count = "${var.enabled}"

  policy_arn = "${data.terraform_remote_state.base.base_policy_arn}"
}

resource "aws_iam_role_policy_attachment" "ci-backup-s3-policy" {
  role = "${aws_iam_role.ci.name}"
  count = "${var.enabled}"

  policy_arn = "${aws_iam_policy.ci-backup-s3-policy.arn}"
}

resource "aws_iam_role_policy_attachment" "alb-rule-editor-policy" {
  role = "${aws_iam_role.ci.name}"
  count = "${var.enabled}"

  policy_arn = "${aws_iam_policy.alb-rule-editor-policy.arn}"
}

resource "aws_iam_policy" "ci-backup-s3-policy" {
  name = "${var.shared["env"]}-ci-backup-s3-policy"
  count = "${var.enabled}"

  policy = <<EOF
{

    "Version": "2012-10-17",
    "Statement": [
      {
          "Effect": "Allow",
          "Action": "s3:GetObject",
          "Resource": "arn:aws:s3:::${data.terraform_remote_state.base.backups_bucket_id}/ci/*"
      },
      {
          "Effect": "Allow",
          "Action": "s3:PutObject",
          "Resource": "arn:aws:s3:::${data.terraform_remote_state.base.backups_bucket_id}/ci/*"
      },
      {
          "Effect": "Allow",
          "Action": "s3:ListBucket",
          "Resource": "arn:aws:s3:::${data.terraform_remote_state.base.backups_bucket_id}"
      }
    ]
  }
EOF
}

resource "aws_iam_policy" "alb-rule-editor-policy" {
  name = "${var.shared["env"]}-alb-rule-editor-policy"
  count = "${var.enabled}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
          "Effect": "Allow",
          "Action": [
            "elasticloadbalancing:DescribeLoadBalancers",
            "elasticloadbalancing:DescribeListeners",
            "elasticloadbalancing:ModifyRule",
            "elasticloadbalancing:DescribeRules",
            "elasticloadbalancing:SetRulePriorities"
          ],
          "Resource": "*"
      }
    ]
  }
EOF
}

resource "aws_iam_role_policy_attachment" "ci-upload-assets-s3-policy" {
  role = "${aws_iam_role.ci.name}"
  count = "${var.enabled}"

  policy_arn = "${aws_iam_policy.ci-upload-assets-s3-policy.arn}"
}

resource "aws_iam_policy" "ci-upload-assets-s3-policy" {
  name = "${var.shared["env"]}-ci-upload-assets-s3-policy"
  count = "${var.enabled}"

  policy = <<EOF
{

    "Version": "2012-10-17",
    "Statement": [
      {
          "Effect": "Allow",
          "Action": "s3:GetObject",
          "Resource": "arn:aws:s3:::${data.terraform_remote_state.base.assets_bucket_id}/*"
      },
      {
          "Effect": "Allow",
          "Action": "s3:PutObject",
          "Resource": "arn:aws:s3:::${data.terraform_remote_state.base.assets_bucket_id}/*"
      },
      {
          "Effect": "Allow",
          "Action": "s3:DeleteObject",
          "Resource": "arn:aws:s3:::${data.terraform_remote_state.base.assets_bucket_id}/*"
      },
      {
          "Effect": "Allow",
          "Action": "s3:PutObjectAcl",
          "Resource": "arn:aws:s3:::${data.terraform_remote_state.base.assets_bucket_id}/*"
      },
      {
          "Effect": "Allow",
          "Action": "s3:ListBucket",
          "Resource": "arn:aws:s3:::${data.terraform_remote_state.base.assets_bucket_id}"
      },
      {
          "Effect": "Allow",
          "Action": "s3:GetObject",
          "Resource": "arn:aws:s3:::${data.terraform_remote_state.base-prod.assets_bucket_id}/*"
      },
      {
          "Effect": "Allow",
          "Action": "s3:DeleteObject",
          "Resource": "arn:aws:s3:::${data.terraform_remote_state.base-prod.assets_bucket_id}/*"
      },
      {
          "Effect": "Allow",
          "Action": "s3:PutObject",
          "Resource": "arn:aws:s3:::${data.terraform_remote_state.base-prod.assets_bucket_id}/*"
      },
      {
          "Effect": "Allow",
          "Action": "s3:PutObjectAcl",
          "Resource": "arn:aws:s3:::${data.terraform_remote_state.base-prod.assets_bucket_id}/*"
      },
      {
          "Effect": "Allow",
          "Action": "s3:ListBucket",
          "Resource": "arn:aws:s3:::${data.terraform_remote_state.base-prod.assets_bucket_id}"
      }
    ]
  }
EOF
}

resource "aws_iam_instance_profile" "ci" {
  name = "${var.shared["env"]}-ci"
  count = "${var.enabled}"

  role = "${aws_iam_role.ci.id}"
}

resource "aws_launch_configuration" "ci" {
  count = "${var.enabled}"

  image_id = "${data.aws_ami.hab-base-ami.id}"
  instance_type = "${var.ci_instance_type}"
  security_groups = [
    "${aws_security_group.ci.id}",
    "${data.terraform_remote_state.hab.hab_ring_security_group_id}",
  ]
  key_name = "${data.terraform_remote_state.base.mr_ssh_key_id}"
  iam_instance_profile = "${aws_iam_instance_profile.ci.id}"
  associate_public_ip_address = false
  lifecycle { create_before_destroy = true }
  root_block_device { volume_size = 128 }
  user_data = <<EOF
#!/usr/bin/env bash
while ! nc -z localhost 9632 ; do sleep 1; done

# Jenkins needs to run hab docker studio as sudo, and read key via hab-pkg-upload/promote
sudo echo '#!/usr/bin/env bash' > /usr/bin/hab-docker-studio
sudo echo 'hab studio -D $@' >> /usr/bin/hab-docker-studio
sudo chmod +x /usr/bin/hab-docker-studio

sudo echo '#!/usr/bin/env bash' > /usr/bin/hab-pkg-upload
sudo echo 'hab pkg upload -z $(cat /hab/cache/keys/mozillareality-github.token) $1' >> /usr/bin/hab-pkg-upload
sudo chmod +x /usr/bin/hab-pkg-upload

sudo echo '#!/usr/bin/env bash' > /usr/bin/hab-pkg-promote
sudo echo 'hab pkg promote -z $(cat /hab/cache/keys/mozillareality-github.token) $1 $2' >> /usr/bin/hab-pkg-promote
sudo chmod +x /usr/bin/hab-pkg-promote

sudo echo '#!/usr/bin/env bash' > /usr/bin/hab-ret-pkg-upload
sudo echo 'hab pkg upload -z $(cat /hab/cache/keys/mozillareality-reticulum.token) $1' >> /usr/bin/hab-ret-pkg-upload
sudo chmod +x /usr/bin/hab-ret-pkg-upload

sudo echo '#!/usr/bin/env bash' > /usr/bin/hab-ret-pkg-promote
sudo echo 'hab pkg promote -z $(cat /hab/cache/keys/mozillareality-reticulum.token) $1 $2' >> /usr/bin/hab-ret-pkg-promote
sudo chmod +x /usr/bin/hab-ret-pkg-promote

sudo echo '#!/usr/bin/env bash' > /usr/bin/hab-pkg-install
sudo echo 'hab pkg install $1' >> /usr/bin/hab-pkg-install
sudo chmod +x /usr/bin/hab-pkg-install

sudo echo '#!/usr/bin/env bash' > /usr/bin/hab-clean-perms
sudo echo 'chown -R hab:hab .' >> /usr/bin/hab-clean-perms
sudo chmod +x /usr/bin/hab-clean-perms

sudo echo "hab ALL=(ALL) NOPASSWD: /usr/bin/hab-docker-studio" >> /etc/sudoers
sudo echo "hab ALL=(ALL) NOPASSWD: /usr/bin/hab-pkg-upload" >> /etc/sudoers
sudo echo "hab ALL=(ALL) NOPASSWD: /usr/bin/hab-pkg-promote" >> /etc/sudoers
sudo echo "hab ALL=(ALL) NOPASSWD: /usr/bin/hab-pkg-install" >> /etc/sudoers
sudo echo "hab ALL=(ALL) NOPASSWD: /usr/bin/hab-user-toml-install" >> /etc/sudoers
sudo echo "hab ALL=(ALL) NOPASSWD: /usr/bin/hab-clean-perms" >> /etc/sudoers

chown root:hab /hab/sup/default
chown root:hab /hab/sup/default/CTL_SECRET
chmod 0750 /hab/sup/default
chmod 0640 /hab/sup/default/CTL_SECRET

sudo apt-get install -y docker.io
sudo /usr/bin/hab svc load mozillareality/jenkins-war --strategy at-once --url https://bldr.habitat.sh --channel stable
EOF
}

resource "aws_autoscaling_group" "ci" {
  name = "${var.shared["env"]}-ci"
  count = "${var.enabled}"

  launch_configuration = "${aws_launch_configuration.ci.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  vpc_zone_identifier = ["${data.terraform_remote_state.vpc.private_subnet_ids}"]

  min_size = "${var.min_ci_servers}"
  max_size = "${var.max_ci_servers}"

  target_group_arns = ["${aws_alb_target_group.ci-alb-group-http.arn}"]

  lifecycle { create_before_destroy = true }
  tag { key = "env", value = "${var.shared["env"]}", propagate_at_launch = true }
  tag { key = "host-type", value = "${var.shared["env"]}-ci", propagate_at_launch = true }
  tag { key = "hab-ring", value = "${var.shared["env"]}", propagate_at_launch = true }
}

resource "aws_security_group" "ci-alb" {
  name = "${var.shared["env"]}-ci-alb"

  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"
}

resource "aws_security_group_rule" "ret-ci-egress" {
  count = "${var.enabled}"

  type = "egress"
  from_port = "8080"
  to_port = "8080"
  protocol = "tcp"
  security_group_id = "${aws_security_group.ci-alb.id}"
  source_security_group_id = "${aws_security_group.ci.id}"
}

resource "aws_alb" "ci-alb" {
  name = "${var.shared["env"]}-ci-alb"
  count = "${var.enabled}"

  internal = false

  security_groups = [
    "${aws_security_group.ci-alb.id}",
    "${data.terraform_remote_state.base.cloudfront_http_security_group_id}",
    "${data.terraform_remote_state.base.cloudfront_https_security_group_id}"
  ]

  subnets = ["${data.terraform_remote_state.vpc.public_subnet_ids}"]

  lifecycle { create_before_destroy = true }
}

resource "aws_alb_target_group" "ci-alb-group-http" {
  name = "${var.shared["env"]}-ci-alb-group-http"
  count = "${var.enabled}"

  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"
  port = "8080"
  protocol = "HTTP"

  health_check {
    path = "/"
    matcher = "200,403"
  }
}

resource "aws_alb_listener" "ci-alb-listener" {
  count = "${var.enabled}"

  load_balancer_arn = "${aws_alb.ci-alb.arn}"
  port = 443

  protocol = "HTTPS"
  ssl_policy = "ELBSecurityPolicy-2015-05"

  certificate_arn = "${data.aws_acm_certificate.ret-wildcard-cert.arn}"

  default_action {
    target_group_arn = "${aws_alb_target_group.ci-alb-group-http.arn}"
    type = "forward"
  }
}

resource "aws_cloudfront_distribution" "ci-external" {
  count = "${var.enabled}"

  enabled = true

  origin {
    origin_id = "reticulum-${var.shared["env"]}-ci"
    domain_name = "ci-origin-${var.shared["env"]}.${var.ret_domain}"

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

  logging_config {
    bucket = "${data.terraform_remote_state.base.logs_bucket_id}.s3.amazonaws.com"
    prefix = "cloudfront/ci-external"
    include_cookies = false
  }

  aliases = ["ci-${var.shared["env"]}.${var.ret_domain}"]

  default_cache_behavior {
    allowed_methods = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods = ["HEAD", "GET"]
    target_origin_id = "reticulum-${var.shared["env"]}-ci"

    forwarded_values {
      query_string = true
      cookies { forward = "all" }
    }

    viewer_protocol_policy = "https-only"
    min_ttl = 0
    default_ttl = 3600
    max_ttl = 3600
  }

  price_class = "PriceClass_All"

  viewer_certificate {
    acm_certificate_arn = "${data.aws_acm_certificate.ret-wildcard-cert-east.arn}"
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1"
  }

  lifecycle {
    ignore_changes = ["web_acl_id"] # Managed manually
  }
}

resource "aws_route53_record" "ci-external-dns" {
  count = "${var.enabled}"

  zone_id = "${data.aws_route53_zone.reticulum-zone.zone_id}"
  name = "ci-${var.shared["env"]}.${data.aws_route53_zone.reticulum-zone.name}"
  type = "A"

  alias {
    name = "${aws_cloudfront_distribution.ci-external.domain_name}"
    zone_id = "${aws_cloudfront_distribution.ci-external.hosted_zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "ci-external-origin-dns" {
  count = "${var.enabled}"

  zone_id = "${data.aws_route53_zone.reticulum-zone.zone_id}"
  name = "ci-origin-${var.shared["env"]}.${data.aws_route53_zone.reticulum-zone.name}"
  type = "A"

  alias {
    name = "${aws_alb.ci-alb.dns_name}"
    zone_id = "${aws_alb.ci-alb.zone_id}"
    evaluate_target_health = false
  }
}
