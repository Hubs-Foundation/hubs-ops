variable "shared" { type = "map" }
terraform { backend "s3" {} }
provider "aws" { region = "${var.shared["region"]}", version = "~> 2.0" }
provider "aws" { alias = "east", region = "us-east-1", version = "~> 2.0" }
data "aws_availability_zones" "all" {}

data "terraform_remote_state" "vpc" { backend = "s3", config = { key = "vpc/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "base" { backend = "s3", config = { key = "base/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "bastion" { backend = "s3", config = { key = "bastion/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "hab" { backend = "s3", config = { key = "hab/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "ret-db" { backend = "s3", config = { key = "ret-db/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }

data "aws_route53_zone" "reticulum-zone" {
  name = "${var.ret_domain}."
}

data "aws_acm_certificate" "ret-alb-listener-cert" {
  domain = "*.${var.ret_domain}"
  statuses = ["ISSUED"]
  most_recent = true
}

data "aws_acm_certificate" "ret-alb-listener-public-cert" {
  domain = "${var.public_domain}"
  statuses = ["ISSUED"]
  most_recent = true
}

data "aws_acm_certificate" "ret-alb-listener-smoke-public-cert" {
  domain = "smoke-${var.public_domain}"
  statuses = ["ISSUED"]
  most_recent = true
}

data "aws_acm_certificate" "ret-alb-listener-cert-east" {
  provider = "aws.east"
  domain = "*.${var.ret_domain}"
  statuses = ["ISSUED"]
  most_recent = true
}

data "aws_ami" "ret-ami" {
  most_recent = true
  owners = ["self"]

  filter {
    name = "name"
    values = ["ret-*"]
  }
}

resource "aws_security_group" "ret-alb" {
  name = "${var.shared["env"]}-ret-alb"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"

  ingress {
    from_port = "80"
    to_port = "80"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = "443"
    to_port = "443"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "ret-alb-egress-ssl" {
  type = "egress"
  from_port = "${var.ret_https_port}"
  to_port = "${var.ret_https_port}"
  protocol = "tcp"
  security_group_id = "${aws_security_group.ret-alb.id}"
  source_security_group_id = "${aws_security_group.ret.id}"
}

resource "aws_route53_record" "ret-alb-dns" {
  zone_id = "${data.aws_route53_zone.reticulum-zone.zone_id}"
  name = "${var.shared["env"]}.${data.aws_route53_zone.reticulum-zone.name}"
  type = "A"

  alias {
    name = "${aws_alb.ret.dns_name}"
    zone_id = "${aws_alb.ret.zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_alb" "ret" {
  name = "${var.shared["env"]}-ret"
  security_groups = ["${aws_security_group.ret-alb.id}"]
  subnets = ["${data.terraform_remote_state.vpc.public_subnet_ids}"]

  lifecycle { create_before_destroy = true }
}

resource "aws_alb_listener_rule" "ret-ssl" {
  listener_arn = "${aws_alb_listener.ret-ssl.arn}"
  count = "${length(var.ret_pools)}"
  
  action {
    type = "forward"
    target_group_arn = "${element(aws_alb_target_group.ret-ssl.*.arn, count.index)}"
  }

  condition {
    field = "path-pattern"
    values = ["/"]
  }

  # Condition managed by tooling
  lifecycle { 
    ignore_changes = [ "condition" ]
  }
}

resource "aws_alb_listener_rule" "ret-smoke-ssl" {
  listener_arn = "${aws_alb_listener.ret-ssl.arn}"
  count = "${length(var.ret_pools)}"
  
  action {
    type = "forward"
    target_group_arn = "${element(aws_alb_target_group.ret-smoke-ssl.*.arn, count.index)}"
  }

  condition {
    field = "path-pattern"
    values = ["/"]
  }

  # Condition managed by tooling
  lifecycle { 
    ignore_changes = [ "condition" ]
  }
}

resource "aws_alb_target_group" "ret-ssl" {
  count = "${length(var.ret_pools)}"
  name = "${var.shared["env"]}-${var.ret_pools[count.index]}-ret-ssl"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"
  port = "${var.ret_https_port}"
  protocol = "HTTPS"
  deregistration_delay = 0

  health_check {
    path = "/health"
    protocol = "HTTPS"
    healthy_threshold = 2
    unhealthy_threshold = 2
    interval = 10
    timeout = 5
  }
}

resource "aws_alb_target_group" "ret-smoke-ssl" {
  count = "${length(var.ret_pools)}"
  name = "${var.shared["env"]}-${var.ret_pools[count.index]}-smoke-ret-ssl"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"
  port = "${var.ret_https_port}"
  protocol = "HTTPS"
  deregistration_delay = 0

  health_check {
    path = "/health"
    protocol = "HTTPS"
    healthy_threshold = 2
    unhealthy_threshold = 2
    interval = 10
    timeout = 5
  }
}

resource "aws_alb_listener" "ret-ssl" {
  load_balancer_arn = "${aws_alb.ret.arn}"
  port = 443

  protocol = "HTTPS"
  ssl_policy = "ELBSecurityPolicy-2015-05"

  certificate_arn = "${data.aws_acm_certificate.ret-alb-listener-cert.arn}"

  default_action {
    target_group_arn = "${element(aws_alb_target_group.ret-ssl.*.arn, 0)}"
    type = "forward"
  }
}

resource "aws_lb_listener_certificate" "ret-ssl-cert" {
  count = "${var.public_domain_enabled}"
  listener_arn = "${aws_alb_listener.ret-ssl.arn}"
  certificate_arn = "${data.aws_acm_certificate.ret-alb-listener-public-cert.arn}"
}

resource "aws_lb_listener_certificate" "ret-smoke-ssl-cert" {
  count = "${var.public_domain_enabled}"
  listener_arn = "${aws_alb_listener.ret-ssl.arn}"
  certificate_arn = "${data.aws_acm_certificate.ret-alb-listener-smoke-public-cert.arn}"
}

resource "aws_alb_listener" "ret-clear" {
  load_balancer_arn = "${aws_alb.ret.arn}"
  port = 80

  protocol = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port = "443"
      protocol = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_s3_bucket" "ret-bucket" {
  bucket = "ret.reticulum-${var.shared["env"]}-${random_id.bucket-identifier.hex}"
  acl = "private"
}

resource "aws_s3_bucket_public_access_block" "ret-bucket-block" {
  bucket = "${aws_s3_bucket.ret-bucket.id}"

  block_public_acls   = true
  block_public_policy = true
}

resource "aws_security_group" "ret" {
  name = "${var.shared["env"]}-ret"
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

  # Outbound SMTP
  egress {
    from_port = "25"
    to_port = "25"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound Janus admin for load balancing
  # HACK: This whitelists for ring overall to avoid cycle between janus/ret terraform scripts
  egress {
    from_port = "7000"
    to_port = "7000"
    protocol = "tcp"
    security_groups = ["${data.terraform_remote_state.hab.hab_ring_security_group_id}"]
  }

  # Reticulum HTTPS
  ingress {
    from_port = "${var.ret_https_port}"
    to_port = "${var.ret_https_port}"
    protocol = "tcp"
    security_groups = ["${aws_security_group.ret-alb.id}"]
  }

  # Reticulum Public HTTPS
  ingress {
    from_port = "${var.ret_public_https_port}"
    to_port = "${var.ret_public_https_port}"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH
  ingress {
    from_port = "22"
    to_port = "22"
    protocol = "tcp"
    security_groups = ["${data.terraform_remote_state.bastion.bastion_security_group_id}"]
  }

  # epmd
  ingress {
    from_port = "4369"
    to_port = "4369"
    protocol = "tcp"
    self = true
  }

  # epmd-udp
  ingress {
    from_port = "4369"
    to_port = "4369"
    protocol = "udp"
    self = true
  }

  # erlang
  ingress {
    from_port = "9000"
    to_port = "9100"
    protocol = "tcp"
    self = true
  }

  # erlang
  egress {
    from_port = "0"
    to_port = "65535"
    protocol = "tcp"
    self = true
  }

  # NTP
  egress {
    from_port = "123"
    to_port = "123"
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # NFS upload-fs
  egress {
    from_port = "2049"
    to_port = "2049"
    protocol = "tcp"
    security_groups = ["${aws_security_group.upload-fs.id}"]
  }
}

resource "aws_iam_role" "ret" {
  name = "${var.shared["env"]}-ret"
  assume_role_policy = "${var.shared["ec2_role_policy"]}"
}

resource "aws_iam_role_policy_attachment" "ret-role-attach" {
  role = "${aws_iam_role.ret.name}"
  policy_arn = "${aws_iam_policy.ret-bucket-policy.arn}"
}

resource "aws_iam_role_policy_attachment" "bastion-base-policy" {
  role = "${aws_iam_role.ret.name}"
  policy_arn = "${data.terraform_remote_state.base.base_policy_arn}"
}

resource "aws_iam_instance_profile" "ret" {
  name = "${var.shared["env"]}-ret"
  role = "${aws_iam_role.ret.id}"
}

resource "aws_cloudfront_distribution" "ret-assets" {
  enabled = true

  origin {
    origin_id = "reticulum-${var.shared["env"]}-assets"
    domain_name = "${data.terraform_remote_state.base.assets_bucket_domain_name}"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  aliases = ["assets-${var.shared["env"]}.${var.ret_domain}"]

  default_cache_behavior {
    compress = true
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = "reticulum-${var.shared["env"]}-assets"

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
    acm_certificate_arn = "${data.aws_acm_certificate.ret-alb-listener-cert-east.arn}"
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1"
  }
}

resource "aws_cloudfront_distribution" "ret-uploads" {
  enabled = true

  origin {
    origin_id = "reticulum-${var.shared["env"]}-uploads"
    domain_name = "${var.shared["env"]}.${var.ret_domain}"

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

  aliases = ["uploads-${var.shared["env"]}.${var.ret_domain}"]

  default_cache_behavior {
    compress = true
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = "reticulum-${var.shared["env"]}-uploads"

    forwarded_values {
      query_string = true
      headers = ["Origin", "Content-Type", "Authorization"]
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
    acm_certificate_arn = "${data.aws_acm_certificate.ret-alb-listener-cert-east.arn}"
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1"
  }
}

resource "aws_route53_record" "ret-uploads-dns" {
  zone_id = "${data.aws_route53_zone.reticulum-zone.zone_id}"
  name = "uploads-${var.shared["env"]}.${data.aws_route53_zone.reticulum-zone.name}"
  type = "A"

  alias {
    name = "${aws_cloudfront_distribution.ret-uploads.domain_name}"
    zone_id = "${aws_cloudfront_distribution.ret-uploads.hosted_zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "ret-assets-dns" {
  zone_id = "${data.aws_route53_zone.reticulum-zone.zone_id}"
  name = "assets-${var.shared["env"]}.${data.aws_route53_zone.reticulum-zone.name}"
  type = "A"

  alias {
    name = "${aws_cloudfront_distribution.ret-assets.domain_name}"
    zone_id = "${aws_cloudfront_distribution.ret-assets.hosted_zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "ret-smoke-alb-dns" {
  zone_id = "${data.aws_route53_zone.reticulum-zone.zone_id}"
  name = "smoke-${var.shared["env"]}.${data.aws_route53_zone.reticulum-zone.name}"
  type = "A"

  alias {
    name = "${aws_alb.ret.dns_name}"
    zone_id = "${aws_alb.ret.zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_launch_configuration" "ret-pool" {
  count = "${length(var.ret_pools)}"
  image_id = "${data.aws_ami.ret-ami.id}"
  instance_type = "${var.ret_instance_type}"
  security_groups = [
    "${aws_security_group.ret.id}",
    "${data.terraform_remote_state.ret-db.ret_db_consumer_security_group_id}",
    "${data.terraform_remote_state.hab.hab_ring_security_group_id}",
  ]
  key_name = "${data.terraform_remote_state.base.mr_ssh_key_id}"
  iam_instance_profile = "${aws_iam_instance_profile.ret.id}"
  associate_public_ip_address = false
  lifecycle { create_before_destroy = true }
  root_block_device { volume_size = 128 }
  user_data = <<EOF
#!/usr/bin/env bash
while ! nc -z localhost 9632 ; do sleep 1; done
systemctl restart systemd-sysctl.service
# Forward port 4000 to 443 for reticulum websockets
sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 4000

sudo mkdir -p /hab/user/reticulum/config

sudo mkdir /uploads
sudo echo "${aws_efs_mount_target.uploads-fs.0.dns_name}:/       /uploads        nfs     nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=3,noresvport" >> /etc/fstab
sudo mount /uploads
sudo chown hab:hab /uploads

sudo cat > /hab/user/reticulum/config/user.toml << EOTOML
[ret]
pool = "${var.ret_pools[count.index]}"

[habitat]
ip = "$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"

[pages]
hubs_page_origin = "https://s3-${var.shared["region"]}.amazonaws.com/${data.terraform_remote_state.base.assets_bucket_id}/hubs/pages/live"
spoke_page_origin = "https://s3-${var.shared["region"]}.amazonaws.com/${data.terraform_remote_state.base.assets_bucket_id}/spoke/pages/live"
EOTOML

aws s3 cp s3://${aws_s3_bucket.ret-bucket.id}/reticulum-files.tar.gz.gpg .
gpg2 -d --pinentry-mode=loopback --passphrase-file=/hab/svc/reticulum/files/gpg-file-key.txt reticulum-files.tar.gz.gpg | tar xz -C /hab/svc/reticulum/files
rm reticulum-files.tar.gz.gpg
chown hab:hab /hab/svc/reticulum/files/*

sudo /usr/bin/hab svc load mozillareality/reticulum --strategy ${var.reticulum_restart_strategy} --url https://bldr.habitat.sh --channel ${var.ret_pools[count.index]}
sudo /usr/bin/hab svc load mozillareality/dd-agent --strategy at-once --url https://bldr.habitat.sh --channel stable
EOF
}

resource "aws_autoscaling_group" "ret-pool" {
  count = "${length(var.ret_pools)}"
  name = "${var.shared["env"]}-${var.ret_pools[count.index]}-ret-pool"
  launch_configuration = "${element(aws_launch_configuration.ret-pool.*.id, count.index)}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  vpc_zone_identifier = ["${data.terraform_remote_state.vpc.public_subnet_ids}"]
  target_group_arns = ["${element(aws_alb_target_group.ret-ssl.*.arn, count.index)}"]

  min_size = "${var.min_ret_servers}"
  max_size = "${var.max_ret_servers}"

  lifecycle { create_before_destroy = true }
  tag { key = "env", value = "${var.shared["env"]}", propagate_at_launch = true }
  tag { key = "host-type", value = "${var.shared["env"]}-ret", propagate_at_launch = true }
  tag { key = "ret-pool", value = "${var.ret_pools[count.index]}", propagate_at_launch = true }
  tag { key = "hab-ring", value = "${var.shared["env"]}", propagate_at_launch = true }
}

resource "aws_launch_configuration" "ret-smoke-pool" {
  count = "${length(var.ret_pools)}"
  image_id = "${data.aws_ami.ret-ami.id}"
  instance_type = "${var.ret_instance_type}"
  security_groups = [
    "${aws_security_group.ret.id}",
    "${data.terraform_remote_state.ret-db.ret_db_consumer_security_group_id}",
    "${data.terraform_remote_state.hab.hab_ring_security_group_id}",
  ]
  key_name = "${data.terraform_remote_state.base.mr_ssh_key_id}"
  iam_instance_profile = "${aws_iam_instance_profile.ret.id}"
  associate_public_ip_address = false
  lifecycle { create_before_destroy = true }
  root_block_device { volume_size = 128 }
  user_data = <<EOF
#!/usr/bin/env bash
while ! nc -z localhost 9632 ; do sleep 1; done
systemctl restart systemd-sysctl.service
# Forward port 4000 to 443 for reticulum websockets
sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 4000

sudo mkdir -p /hab/user/reticulum/config

sudo mkdir /uploads
sudo echo "${aws_efs_mount_target.uploads-fs.0.dns_name}:/       /uploads        nfs     nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=3,noresvport" >> /etc/fstab
sudo mount /uploads
sudo chown hab:hab /uploads

sudo cat > /hab/user/reticulum/config/user.toml << EOTOML
[ret]
pool = "${var.ret_pools[count.index]}"

[phx]
url_host_prefix = "smoke-"
static_url_host_prefix = "smoke-"

[habitat]
ip = "$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"

[pages]
hubs_page_origin = "https://s3-${var.shared["region"]}.amazonaws.com/${data.terraform_remote_state.base.assets_bucket_id}/hubs/pages/latest"
spoke_page_origin = "https://s3-${var.shared["region"]}.amazonaws.com/${data.terraform_remote_state.base.assets_bucket_id}/spoke/pages/latest"
EOTOML

aws s3 cp s3://${aws_s3_bucket.ret-bucket.id}/reticulum-files.tar.gz.gpg .
gpg2 -d --pinentry-mode=loopback --passphrase-file=/hab/svc/reticulum/files/gpg-file-key.txt reticulum-files.tar.gz.gpg | tar xz -C /hab/svc/reticulum/files
rm reticulum-files.tar.gz.gpg
chown hab:hab /hab/svc/reticulum/files/*

sudo /usr/bin/hab svc load mozillareality/reticulum --strategy ${var.reticulum_restart_strategy} --url https://bldr.habitat.sh --channel ${var.ret_pools[count.index]}
sudo /usr/bin/hab svc load mozillareality/dd-agent --strategy at-once --url https://bldr.habitat.sh --channel stable
EOF
}

resource "aws_autoscaling_group" "ret-smoke-pool" {
  count = "${length(var.ret_pools)}"
  name = "${var.shared["env"]}-${var.ret_pools[count.index]}-ret-smoke-pool"
  launch_configuration = "${element(aws_launch_configuration.ret-smoke-pool.*.id, count.index)}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  vpc_zone_identifier = ["${data.terraform_remote_state.vpc.public_subnet_ids}"]
  target_group_arns = ["${element(aws_alb_target_group.ret-smoke-ssl.*.arn, count.index)}"]

  min_size = "1"
  max_size = "1"

  lifecycle { create_before_destroy = true }
  tag { key = "env", value = "${var.shared["env"]}", propagate_at_launch = true }
  tag { key = "host-type", value = "${var.shared["env"]}-ret", propagate_at_launch = true }
  tag { key = "hab-ring", value = "${var.shared["env"]}", propagate_at_launch = true }
  tag { key = "ret-pool", value = "${var.ret_pools[count.index]}", propagate_at_launch = true }
  tag { key = "smoke", value = "true", propagate_at_launch = true }
}

resource "aws_cloudfront_distribution" "ret-asset-bundles" {
  enabled = true

  origin {
    origin_id = "reticulum-${var.shared["env"]}-asset-bundles"
    domain_name = "${data.terraform_remote_state.base.asset_bundles_bucket_domain_name}"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  aliases = ["asset-bundles-${var.shared["env"]}.${var.ret_domain}"]

  default_cache_behavior {
    compress = true
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = "reticulum-${var.shared["env"]}-asset-bundles"

    forwarded_values {
      query_string = true
      headers = ["Origin"]
      cookies { forward = "none" }
    }

    viewer_protocol_policy = "https-only"
    min_ttl = 0
    default_ttl = 3600
    max_ttl = 3600
  }

  price_class = "PriceClass_All"

  viewer_certificate {
    acm_certificate_arn = "${data.aws_acm_certificate.ret-alb-listener-cert-east.arn}"
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1"
  }
}

resource "aws_route53_record" "ret-assets-bundles-dns" {
  zone_id = "${data.aws_route53_zone.reticulum-zone.zone_id}"
  name = "asset-bundles-${var.shared["env"]}.${data.aws_route53_zone.reticulum-zone.name}"
  type = "A"

  alias {
    name = "${aws_cloudfront_distribution.ret-asset-bundles.domain_name}"
    zone_id = "${aws_cloudfront_distribution.ret-asset-bundles.hosted_zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_cloudfront_distribution" "timecheck" {
  enabled = true

  origin {
    origin_id = "${var.shared["env"]}-timecheck"
    domain_name = "${data.terraform_remote_state.base.timecheck_bucket_website_endpoint}"

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

  aliases = ["timecheck-${var.shared["env"]}.${var.ret_domain}"]

  default_cache_behavior {
    compress = true
    allowed_methods = ["HEAD", "GET"]
    cached_methods = ["HEAD", "GET"]
    target_origin_id = "${var.shared["env"]}-timecheck"

    forwarded_values {
      query_string = true
      headers = ["Origin"]
      cookies { forward = "none" }
    }

    viewer_protocol_policy = "https-only"
    min_ttl = 0
    default_ttl = 0
    max_ttl = 0
  }

  price_class = "PriceClass_All"

  viewer_certificate {
    acm_certificate_arn = "${data.aws_acm_certificate.ret-alb-listener-cert-east.arn}"
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1"
  }
}

resource "aws_route53_record" "timecheck-dns" {
  zone_id = "${data.aws_route53_zone.reticulum-zone.zone_id}"
  name = "timecheck-${var.shared["env"]}.${data.aws_route53_zone.reticulum-zone.name}"
  type = "A"

  alias {
    name = "${aws_cloudfront_distribution.timecheck.domain_name}"
    zone_id = "${aws_cloudfront_distribution.timecheck.hosted_zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_efs_file_system" "uploads-fs" {
  creation_token = "${var.shared["env"]}-uploads"
  performance_mode = "generalPurpose"
}

resource "aws_efs_mount_target" "uploads-fs" {
  file_system_id = "${aws_efs_file_system.uploads-fs.id}"
  subnet_id = "${element(data.terraform_remote_state.vpc.private_subnet_ids, count.index)}"
  security_groups = ["${aws_security_group.upload-fs.id}"]
  count = "${length(data.terraform_remote_state.vpc.private_subnet_ids)}"
}

resource "aws_security_group" "upload-fs" {
  name = "${var.shared["env"]}-upload-fs"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"
}

resource "aws_security_group_rule" "ret-upload-fs-ingress" {
  type = "ingress"
  from_port = "2049"
  to_port = "2049"
  protocol = "tcp"
  security_group_id = "${aws_security_group.upload-fs.id}"
  source_security_group_id = "${aws_security_group.ret.id}"
}

resource "random_id" "bucket-identifier" {
  byte_length = 8
}

resource "aws_s3_bucket" "upload-backup-bucket" {
  bucket = "ret-upload-backup-${var.shared["env"]}-${random_id.bucket-identifier.hex}"
  acl = "private"
}

resource "aws_iam_role_policy_attachment" "ret-upload-backup-role-attach" {
  role = "${aws_iam_role.ret.name}"
  policy_arn = "${aws_iam_policy.ret-upload-backup-policy.arn}"
}

resource "aws_iam_policy" "ret-bucket-policy" {
  name = "${var.shared["env"]}-ret-bucket-policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Action": "s3:GetObject",
        "Resource": "arn:aws:s3:::${aws_s3_bucket.ret-bucket.id}/*"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "ret-upload-backup-policy" {
  name = "${var.shared["env"]}-ret-upload-backup-policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Action": "s3:GetObject",
        "Resource": "arn:aws:s3:::${aws_s3_bucket.upload-backup-bucket.id}/*"
    },
    {
        "Effect": "Allow",
        "Action": "s3:PutObject",
        "Resource": "arn:aws:s3:::${aws_s3_bucket.upload-backup-bucket.id}/*"
    },
    {
        "Effect": "Allow",
        "Action": "s3:ListBucket",
        "Resource": "arn:aws:s3:::${aws_s3_bucket.upload-backup-bucket.id}"
    }
  ]
}
EOF
}
