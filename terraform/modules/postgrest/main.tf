variable "shared" { type = "map" }
terraform { backend "s3" {} }
provider "aws" { region = "${var.shared["region"]}", version = "~> 1.15" }
provider "aws" { alias = "east", region = "us-east-1", version = "~> 1.15" }
data "aws_availability_zones" "all" {}

data "terraform_remote_state" "vpc" { backend = "s3", config = { key = "vpc/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "base" { backend = "s3", config = { key = "base/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "bastion" { backend = "s3", config = { key = "bastion/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "hab" { backend = "s3", config = { key = "hab/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "ret-db" { backend = "s3", config = { key = "ret-db/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "ret" { backend = "s3", config = { key = "ret/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }

data "aws_route53_zone" "postgrest-zone" {
  name = "${var.postgrest_domain}."
}

data "aws_ami" "hab-census-ami" {
  most_recent = true
  owners = ["self"]

  filter {
    name = "name"
    values = ["hab-census-*"]
  }
}

data "aws_acm_certificate" "postgrest-alb-listener-cert" {
  domain = "*.${var.postgrest_domain}"
  statuses = ["ISSUED"]
  most_recent = true
}

data "aws_acm_certificate" "postgrest-alb-listener-cert-east" {
  provider = "aws.east"
  domain = "*.${var.postgrest_domain}"
  statuses = ["ISSUED"]
  most_recent = true
}

resource "aws_security_group" "postgrest-alb" {
  name = "${var.shared["env"]}-postgrest-alb"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"

  ingress {
    from_port = "${var.postgrest_http_port}"
    to_port = "${var.postgrest_http_port}"
    protocol = "tcp"
    security_groups = ["${data.terraform_remote_state.bastion.bastion_security_group_id}"]
  }
}

resource "aws_security_group_rule" "postgrest-alb-egress" {
  type = "egress"
  from_port = "${var.postgrest_http_port}"
  to_port = "${var.postgrest_http_port}"
  protocol = "tcp"
  security_group_id = "${aws_security_group.postgrest-alb.id}"
  source_security_group_id = "${aws_security_group.postgrest.id}"
}

resource "aws_alb" "postgrest-alb" {
  name = "${var.shared["env"]}-postgrest-alb"

  security_groups = [
    "${aws_security_group.postgrest-alb.id}"
  ]

  subnets = ["${data.terraform_remote_state.vpc.private_subnet_ids}"]
  internal = true

  lifecycle { create_before_destroy = true }
}

resource "aws_alb_target_group" "postgrest-alb-group-http" {
  name = "${var.shared["env"]}-postgrest-alb-group-http"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"
  port = "${var.postgrest_http_port}"
  protocol = "HTTP"
  deregistration_delay = 0

  health_check {
    path = "/"
    healthy_threshold = 2
    unhealthy_threshold = 2
    interval = 10
    timeout = 5
  }
}

resource "aws_alb_listener" "postgrest-ssl-alb-listener" {
  load_balancer_arn = "${aws_alb.postgrest-alb.arn}"
  port = "${var.postgrest_http_port}"

  protocol = "HTTPS"
  ssl_policy = "ELBSecurityPolicy-2015-05"

  certificate_arn = "${data.aws_acm_certificate.postgrest-alb-listener-cert.arn}"

  default_action {
    target_group_arn = "${aws_alb_target_group.postgrest-alb-group-http.arn}"
    type = "forward"
  }
}

resource "aws_security_group" "postgrest" {
  name = "${var.shared["env"]}-postgrest"
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

  # PostgREST HTTP
  ingress {
    from_port = "${var.postgrest_http_port}"
    to_port = "${var.postgrest_http_port}"
    protocol = "tcp"
    security_groups = ["${aws_security_group.postgrest-alb.id}"]
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
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "postgrest" {
  name = "${var.shared["env"]}-postgrest"
  assume_role_policy = "${var.shared["ec2_role_policy"]}"
}

resource "aws_iam_role_policy_attachment" "bastion-base-policy" {
  role = "${aws_iam_role.postgrest.name}"
  policy_arn = "${data.terraform_remote_state.base.base_policy_arn}"
}

resource "aws_iam_instance_profile" "postgrest" {
  name = "${var.shared["env"]}-postgrest"
  role = "${aws_iam_role.postgrest.id}"
}

resource "aws_launch_configuration" "postgrest" {
  image_id = "${data.aws_ami.hab-census-ami.id}"
  instance_type = "${var.postgrest_instance_type}"
  security_groups = [
    "${aws_security_group.postgrest.id}",
    "${data.terraform_remote_state.ret-db.ret_db_consumer_security_group_id}",
    "${data.terraform_remote_state.hab.hab_ring_security_group_id}",
  ]
  key_name = "${data.terraform_remote_state.base.mr_ssh_key_id}"
  iam_instance_profile = "${aws_iam_instance_profile.postgrest.id}"
  associate_public_ip_address = false
  lifecycle { create_before_destroy = true }
  root_block_device { volume_size = 64 }
  user_data = <<EOF
#!/usr/bin/env bash
while ! nc -z localhost 9632 ; do sleep 1; done
systemctl restart systemd-sysctl.service

sudo /usr/bin/hab svc load mozillareality/postgrest --strategy ${var.postgrest_restart_strategy} --url https://bldr.habitat.sh --channel ${var.postgrest_channel}
sudo /usr/bin/hab svc load mozillareality/telegraf --strategy at-once --url https://bldr.habitat.sh --channel stable
sudo /usr/bin/python /usr/bin/save_service_files postgrest default mozillareality
EOF
}

resource "aws_autoscaling_group" "postgrest" {
  name = "${var.shared["env"]}-postgrest"
  launch_configuration = "${aws_launch_configuration.postgrest.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  vpc_zone_identifier = ["${data.terraform_remote_state.vpc.private_subnet_ids}"]

  min_size = "1"
  max_size = "1"

  target_group_arns = ["${aws_alb_target_group.postgrest-alb-group-http.arn}"]

  lifecycle { create_before_destroy = true }
  tag { key = "env", value = "${var.shared["env"]}", propagate_at_launch = true }
  tag { key = "host-type", value = "${var.shared["env"]}-postgrest", propagate_at_launch = true }
  tag { key = "hab-ring", value = "${var.shared["env"]}", propagate_at_launch = true }
}

resource "aws_route53_record" "postgrest-dns" {
  zone_id = "${data.aws_route53_zone.postgrest-zone.zone_id}"
  name = "${var.postgrest_dns_prefix}${data.aws_route53_zone.postgrest-zone.name}"
  type = "A"

  alias {
    name = "${aws_alb.postgrest-alb.dns_name}"
    zone_id = "${aws_alb.postgrest-alb.zone_id}"
    evaluate_target_health = true
  }
}
