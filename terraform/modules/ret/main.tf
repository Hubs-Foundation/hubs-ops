
variable "shared" { type = "map" }
terraform { backend "s3" {} }
provider "aws" { region = "${var.shared["region"]}", version = "~> 0.1" }
data "aws_availability_zones" "all" {}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    key = "vpc/terraform.tfstate"
    bucket = "${var.shared["state_bucket"]}"
    region = "${var.shared["region"]}"
    dynamodb_table = "${var.shared["dynamodb_table"]}"
    encrypt = "true"
  }
}

data "terraform_remote_state" "keys" {
  backend = "s3"
  config = {
    key = "keys/terraform.tfstate"
    bucket = "${var.shared["state_bucket"]}"
    region = "${var.shared["region"]}"
    dynamodb_table = "${var.shared["dynamodb_table"]}"
    encrypt = "true"
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

resource "aws_alb" "ret-alb" {
  name = "${var.shared["env"]}-ret-alb"
  security_groups = ["${aws_security_group.ret-alb.id}"]
  subnets = ["${data.terraform_remote_state.vpc.public_subnet_ids}"]
  
  lifecycle { create_before_destroy = true }
}

resource "aws_alb_target_group" "ret-alb-group-http" {
  name = "${var.shared["env"]}-ret-alb-group-http"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"
  port = "${var.ret_http_port}"
  protocol = "HTTP"

  health_check {
    path = "/health_check"
  }
}

# TODO
#data "aws_acm_certificate" "ret-alb-listener-cert" {
#  domain = "reticulum.mozilla.com"
#  statuses = ["ISSUED"]
#}

resource "aws_alb_listener" "ret-alb-listener" {
  load_balancer_arn = "${aws_alb.ret-alb.arn}"
  port = 443
  protocol = "HTTP"

  # TODO
  # protocol = "HTTPS"
  # ssl_policy = "ELBSecurityPolicy-2015-05"
  # certificate_arn = "${aws_acm_certificate.ret-alb.listener-cert.arn}"
  
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

  ingress {
    from_port = "${var.ret_http_port}"
    to_port = "${var.ret_http_port}"
    protocol = "tcp"
    security_groups = ["${aws_security_group.ret-alb.id}"]
  }

  ingress {
    from_port = "${var.ret_webrtc_port}"
    to_port = "${var.ret_webrtc_port}"
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH
  ingress {
    from_port = "22"
    to_port = "22"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow intra-sg crosstalk (OTP, habitat)
  ingress {
    from_port = "0"
    to_port = "65535"
    protocol = "tcp"
    self = true
  }
}

resource "aws_iam_role" "ret" {
  name = "${var.shared["env"]}-ret"
  assume_role_policy = "${var.shared["ec2_role_policy"]}"
}

resource "aws_iam_instance_profile" "ret" {
  name = "${var.shared["env"]}-ret"
  role = "${aws_iam_role.ret.id}"
}

resource "aws_iam_policy" "ret-describe-instances" {
  name = "${var.shared["env"]}-ret-describe-instances"
  policy = "${var.shared["describe_instances_policy"]}"
}

resource "aws_iam_role_policy_attachment" "ret-attach-describe-instances" {
  role = "${aws_iam_role.ret.name}"
  policy_arn = "${aws_iam_policy.ret-describe-instances.arn}"
}

resource "aws_launch_configuration" "ret" {
  image_id = "${var.ret_ami}"
  instance_type = "${var.ret_instance_type}"
  security_groups = ["${aws_security_group.ret.id}"]
  key_name = "${data.terraform_remote_state.keys.mr_ssh_key_id}"
  iam_instance_profile = "${aws_iam_instance_profile.ret.id}"
  associate_public_ip_address = true
  lifecycle { create_before_destroy = true }
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
  tag { key = "Name", value = "${var.shared["env"]}-ret", propagate_at_launch = true }
}
