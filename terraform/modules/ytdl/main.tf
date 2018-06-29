variable "shared" { type = "map" }
terraform { backend "s3" {} }
provider "aws" { region = "${var.shared["region"]}", version = "~> 1.15" }
provider "aws" { alias = "east", region = "us-east-1", version = "~> 1.15" }
data "aws_availability_zones" "all" {}

data "terraform_remote_state" "vpc" { backend = "s3", config = { key = "vpc/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "base" { backend = "s3", config = { key = "base/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "bastion" { backend = "s3", config = { key = "bastion/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "hab" { backend = "s3", config = { key = "hab/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "ret" { backend = "s3", config = { key = "ret/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }

data "aws_route53_zone" "ytdl-zone" {
  name = "${var.ytdl_domain}."
}

data "aws_acm_certificate" "ytdl-alb-listener-cert" {
  domain = "*.${var.ytdl_domain}"
  statuses = ["ISSUED"]
  most_recent = true
}

data "aws_acm_certificate" "ytdl-alb-listener-cert-east" {
  provider = "aws.east"
  domain = "*.${var.ytdl_domain}"
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

resource "aws_security_group" "ytdl-alb" {
  name = "${var.shared["env"]}-ytdl-alb"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"

  ingress {
    from_port = "443"
    to_port = "443"
    protocol = "tcp"
    security_groups = ["${data.terraform_remote_state.ret.ret_security_group_id}"]
  }
}

resource "aws_security_group_rule" "ytdl-alb-egress" {
  type = "egress"
  from_port = "${var.ytdl_http_port}"
  to_port = "${var.ytdl_http_port}"
  protocol = "tcp"
  security_group_id = "${aws_security_group.ytdl-alb.id}"
  source_security_group_id = "${aws_security_group.ytdl.id}"
}

resource "aws_alb" "ytdl-alb" {
  name = "${var.shared["env"]}-ytdl-alb"

  security_groups = [
    "${aws_security_group.ytdl-alb.id}"
  ]

  subnets = ["${data.terraform_remote_state.vpc.private_subnet_ids}"]

  lifecycle { create_before_destroy = true }
}

resource "aws_alb_target_group" "ytdl-alb-group-http" {
  name = "${var.shared["env"]}-ytdl-alb-group-http"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"
  port = "${var.ytdl_http_port}"
  protocol = "HTTP"
  deregistration_delay = 0

  health_check {
    path = "/api/version"
    healthy_threshold = 2
    unhealthy_threshold = 2
    interval = 10
    timeout = 5
  }
}

resource "aws_alb_listener" "ytdl-ssl-alb-listener" {
  load_balancer_arn = "${aws_alb.ytdl-alb.arn}"
  port = 443

  protocol = "HTTPS"
  ssl_policy = "ELBSecurityPolicy-2015-05"

  certificate_arn = "${data.aws_acm_certificate.ytdl-alb-listener-cert.arn}"

  default_action {
    target_group_arn = "${aws_alb_target_group.ytdl-alb-group-http.arn}"
    type = "forward"
  }
}

resource "aws_security_group" "ytdl" {
  name = "${var.shared["env"]}-ytdl"
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

  # YT-DL HTTP
  ingress {
    from_port = "${var.ytdl_http_port}"
    to_port = "${var.ytdl_http_port}"
    protocol = "tcp"
    security_groups = ["${aws_security_group.ytdl-alb.id}"]
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

resource "aws_iam_role" "ytdl" {
  name = "${var.shared["env"]}-ytdl"
  assume_role_policy = "${var.shared["ec2_role_policy"]}"
}

resource "aws_iam_role_policy_attachment" "bastion-base-policy" {
  role = "${aws_iam_role.ytdl.name}"
  policy_arn = "${data.terraform_remote_state.base.base_policy_arn}"
}

resource "aws_iam_instance_profile" "ytdl" {
  name = "${var.shared["env"]}-ytdl"
  role = "${aws_iam_role.ytdl.id}"
}

resource "aws_launch_configuration" "ytdl" {
  image_id = "${data.aws_ami.hab-base-ami.id}"
  instance_type = "${var.ytdl_instance_type}"
  security_groups = [
    "${aws_security_group.ytdl.id}",
    "${data.terraform_remote_state.hab.hab_ring_security_group_id}",
  ]
  key_name = "${data.terraform_remote_state.base.mr_ssh_key_id}"
  iam_instance_profile = "${aws_iam_instance_profile.ytdl.id}"
  associate_public_ip_address = false
  lifecycle { create_before_destroy = true }
  root_block_device { volume_size = 64 }
  user_data = <<EOF
#!/usr/bin/env bash
while ! nc -z localhost 9632 ; do sleep 1; done
systemctl restart systemd-sysctl.service

sudo /usr/bin/hab svc load mozillareality/youtube-dl-api-server --strategy ${var.ytdl_restart_strategy} --url https://bldr.habitat.sh --channel ${var.ytdl_channel}
sudo /usr/bin/hab svc load mozillareality/dd-agent --strategy at-once --url https://bldr.habitat.sh --channel stable
EOF
}

resource "aws_autoscaling_group" "ytdl" {
  name = "${var.shared["env"]}-ytdl"
  launch_configuration = "${aws_launch_configuration.ytdl.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  vpc_zone_identifier = ["${data.terraform_remote_state.vpc.private_subnet_ids}"]

  min_size = "${var.min_ytdl_servers}"
  max_size = "${var.max_ytdl_servers}"

  target_group_arns = ["${aws_alb_target_group.ytdl-alb-group-http.arn}"]

  lifecycle { create_before_destroy = true }
  tag { key = "env", value = "${var.shared["env"]}", propagate_at_launch = true }
  tag { key = "host-type", value = "${var.shared["env"]}-ytdl", propagate_at_launch = true }
  tag { key = "hab-ring", value = "${var.shared["env"]}", propagate_at_launch = true }
}

resource "aws_route53_record" "ytdl-dns" {
  zone_id = "${data.aws_route53_zone.ytdl-zone.zone_id}"
  name = "${var.ytdl_dns_prefix}${data.aws_route53_zone.ytdl-zone.name}"
  type = "A"

  alias {
    name = "${aws_alb.ytdl-alb.dns_name}"
    zone_id = "${aws_alb.ytdl-alb.zone_id}"
    evaluate_target_health = true
  }
}
