variable "shared" { type = "map" }
terraform { backend "s3" {} }
provider "aws" { region = "${var.shared["region"]}", version = "~> 0.1" }
data "aws_availability_zones" "all" {}

data "terraform_remote_state" "vpc" { backend = "s3", config = { key = "vpc/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "base" { backend = "s3", config = { key = "base/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "bastion" { backend = "s3", config = { key = "bastion/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "hab" { backend = "s3", config = { key = "hab/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "ret-db" { backend = "s3", config = { key = "ret-db/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }

data "aws_route53_zone" "reticulum-zone" {
  name = "reticulum.io."
}

data "aws_acm_certificate" "ret-alb-listener-cert" {
  domain = "*.reticulum.io"
  statuses = ["ISSUED"]
}

data "aws_ami" "hab-base-ami" {
  most_recent = true
  owners = ["self"]

  filter {
    name = "name"
    values = ["hab-base-*"]
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

resource "aws_security_group_rule" "ret-alb-egress" {
  type = "egress"
  from_port = "${var.ret_http_port}"
  to_port = "${var.ret_http_port}"
  protocol = "tcp"
  security_group_id = "${aws_security_group.ret-alb.id}"
  source_security_group_id = "${aws_security_group.ret.id}"
}

resource "aws_alb" "ret-alb" {
  name = "${var.shared["env"]}-ret-alb"
  security_groups = ["${aws_security_group.ret-alb.id}"]
  subnets = ["${data.terraform_remote_state.vpc.public_subnet_ids}"]
  
  lifecycle { create_before_destroy = true }
}

resource "aws_route53_record" "ret-alb-dns" {
  zone_id = "${data.aws_route53_zone.reticulum-zone.zone_id}"
  name = "${var.shared["env"]}.${data.aws_route53_zone.reticulum-zone.name}"
  type = "A"

  alias {
    name = "${aws_alb.ret-alb.dns_name}"
    zone_id = "${aws_alb.ret-alb.zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_alb_target_group" "ret-alb-group-http" {
  name = "${var.shared["env"]}-ret-alb-group-http"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"
  port = "${var.ret_http_port}"
  protocol = "HTTP"

  health_check {
    path = "/"
  }
}

resource "aws_alb_listener" "ret-alb-listener" {
  load_balancer_arn = "${aws_alb.ret-alb.arn}"
  port = 443

  protocol = "HTTPS"
  ssl_policy = "ELBSecurityPolicy-2015-05"

  certificate_arn = "${data.aws_acm_certificate.ret-alb-listener-cert.arn}"
  
  default_action {
    target_group_arn = "${aws_alb_target_group.ret-alb-group-http.arn}"
    type = "forward"
  }
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

  # WebRTC RTP egress
  egress {
    from_port = "0"
    to_port = "65535"
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Reticulum HTTP
  ingress {
    from_port = "${var.ret_http_port}"
    to_port = "${var.ret_http_port}"
    protocol = "tcp"
    security_groups = ["${aws_security_group.ret-alb.id}"]
  }

  # Janus Websockets
  ingress {
    from_port = "${var.janus_wss_port}"
    to_port = "${var.janus_wss_port}"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  # Janus Admin via bastion
  ingress {
    from_port = "${var.janus_admin_port}"
    to_port = "${var.janus_admin_port}"
    protocol = "tcp"
    security_groups = ["${data.terraform_remote_state.bastion.bastion_security_group_id}"]
  }

  # Janus RTP
  ingress {
    from_port = "${var.janus_rtp_port_from}"
    to_port = "${var.janus_rtp_port_to}"
    protocol = "udp"
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

  # epmd
  egress {
    from_port = "4369"
    to_port = "4369"
    protocol = "tcp"
    self = true
  }

  # epmd-udp
  egress {
    from_port = "4369"
    to_port = "4369"
    protocol = "udp"
    self = true
  }

  # erlang
  egress {
    from_port = "9000"
    to_port = "9100"
    protocol = "tcp"
    self = true
  }

  # Papertrail
  egress {
    from_port = "28666"
    to_port = "28666"
    protocol = "tcp"
    cidr_blocks = ["169.46.82.160/27"]
  }

  # NTP
  egress {
    from_port = "123"
    to_port = "123"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "ret" {
  name = "${var.shared["env"]}-ret"
  assume_role_policy = "${var.shared["ec2_role_policy"]}"
}

resource "aws_iam_role_policy_attachment" "bastion-base-policy" {
  role = "${aws_iam_role.ret.name}"
  policy_arn = "${data.terraform_remote_state.base.base_policy_arn}"
}

resource "aws_iam_instance_profile" "ret" {
  name = "${var.shared["env"]}-ret"
  role = "${aws_iam_role.ret.id}"
}

resource "aws_launch_configuration" "ret" {
  image_id = "${data.aws_ami.hab-base-ami.id}"
  instance_type = "${var.ret_instance_type}"
  security_groups = [
    "${aws_security_group.ret.id}",
    "${data.terraform_remote_state.ret-db.ret_db_consumer_security_group_id}",
    "${data.terraform_remote_state.hab.hab_ring_security_group_id}",
  ]
  key_name = "${data.terraform_remote_state.base.mr_ssh_key_id}"
  iam_instance_profile = "${aws_iam_instance_profile.ret.id}"
  associate_public_ip_address = true
  lifecycle { create_before_destroy = true }
  user_data = <<EOF
#!/usr/bin/env bash
while ! [ -f /hab/sup/default/MEMBER_ID ] ; do sleep 1; done
# Forward port 8080 to 80, 8443 to 443 for janus websockets
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443

sudo /usr/bin/hab start mozillareality/janus-gateway --strategy at-once --url https://bldr.habitat.sh --channel stable
sudo /usr/bin/hab start mozillareality/reticulum --strategy at-once --url https://bldr.habitat.sh --channel stable
EOF
}

resource "aws_autoscaling_group" "ret" {
  name = "${var.shared["env"]}-ret"
  launch_configuration = "${aws_launch_configuration.ret.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  vpc_zone_identifier = ["${data.terraform_remote_state.vpc.public_subnet_ids}"]

  min_size = "${var.min_ret_servers}"
  max_size = "${var.max_ret_servers}"

  target_group_arns = ["${aws_alb_target_group.ret-alb-group-http.arn}"]

  lifecycle { create_before_destroy = true }
  tag { key = "env", value = "${var.shared["env"]}", propagate_at_launch = true }
  tag { key = "host-type", value = "${var.shared["env"]}-ret", propagate_at_launch = true }
  tag { key = "hab-ring", value = "${var.shared["env"]}", propagate_at_launch = true }
}
