variable "shared" { type = "map" }
terraform { backend "s3" {} }
provider "aws" { region = "${var.shared["region"]}", version = "~> 0.1" }
provider "aws" { alias = "east", region = "us-east-1", version = "~> 0.1" }
data "aws_availability_zones" "all" {}

data "terraform_remote_state" "vpc" { backend = "s3", config = { key = "vpc/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "base" { backend = "s3", config = { key = "base/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "bastion" { backend = "s3", config = { key = "bastion/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "hab" { backend = "s3", config = { key = "hab/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }

data "aws_ami" "hab-base-ami" {
  most_recent = true
  owners = ["self"]

  filter {
    name = "name"
    values = ["hab-base-*"]
  }
}

resource "aws_security_group" "janus" {
  name = "${var.shared["env"]}-janus"
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

  # Janus HTTPS
  ingress {
    from_port = "${var.janus_https_port}"
    to_port = "${var.janus_https_port}"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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

  # Janus RTP-over-UDP
  ingress {
    from_port = "${var.janus_rtp_port_from}"
    to_port = "${var.janus_rtp_port_to}"
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Janus RTP-over-TCP
  ingress {
    from_port = "${var.janus_rtp_port_from}"
    to_port = "${var.janus_rtp_port_to}"
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

  # NTP
  egress {
    from_port = "123"
    to_port = "123"
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "janus" {
  name = "${var.shared["env"]}-janus"
  assume_role_policy = "${var.shared["ec2_role_policy"]}"
}

resource "aws_iam_role_policy_attachment" "bastion-base-policy" {
  role = "${aws_iam_role.janus.name}"
  policy_arn = "${data.terraform_remote_state.base.base_policy_arn}"
}

resource "aws_iam_instance_profile" "janus" {
  name = "${var.shared["env"]}-janus"
  role = "${aws_iam_role.janus.id}"
}

resource "aws_launch_configuration" "janus" {
  image_id = "${data.aws_ami.hab-base-ami.id}"
  instance_type = "${var.janus_instance_type}"
  security_groups = [
    "${aws_security_group.janus.id}",
    "${data.terraform_remote_state.hab.hab_ring_security_group_id}",
  ]
  key_name = "${data.terraform_remote_state.base.mr_ssh_key_id}"
  iam_instance_profile = "${aws_iam_instance_profile.janus.id}"
  associate_public_ip_address = true
  lifecycle { create_before_destroy = true }
  root_block_device { volume_size = 128 }
  user_data = <<EOF
#!/usr/bin/env bash
while ! nc -z localhost 9632 ; do sleep 1; done
systemctl restart systemd-sysctl.service
# Forward port 8080 to 80, 8443 to 443 for janus websockets
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443

sudo mkdir -p /hab/user/janus-gateway/config

sudo cat > /etc/cron.d/janus-restart << EOCRON
0 10 * * * hab killall janus
EOCRON

/etc/init.d/cron reload

sudo cat > /hab/user/janus-gateway/config/user.toml << EOTOML
[nat]
nat_1_1_mapping = "$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"

[transports.http]
admin_ip = "$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
EOTOML

sudo sed -i "s/#RateLimitBurst=1000/RateLimitBurst=5000/" /etc/systemd/journald.conf
sudo systemctl restart systemd-journald

sudo /usr/bin/hab svc load mozillareality/janus-gateway --strategy ${var.janus_restart_strategy} --url https://bldr.habitat.sh --channel ${var.janus_channel}
sudo /usr/bin/hab svc load mozillareality/dd-agent --strategy at-once --url https://bldr.habitat.sh --channel stable
sudo /usr/bin/python /usr/bin/save_service_files janus-gateway default mozillareality
EOF
}

resource "aws_autoscaling_group" "janus" {
  name = "${var.shared["env"]}-janus"
  launch_configuration = "${aws_launch_configuration.janus.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  vpc_zone_identifier = ["${data.terraform_remote_state.vpc.public_subnet_ids}"]

  min_size = "1"
  max_size = "1"

  lifecycle { create_before_destroy = true }
  tag { key = "env", value = "${var.shared["env"]}", propagate_at_launch = true }
  tag { key = "host-type", value = "${var.shared["env"]}-janus", propagate_at_launch = true }
  tag { key = "hab-ring", value = "${var.shared["env"]}", propagate_at_launch = true }
}

resource "aws_launch_configuration" "janus-smoke" {
  image_id = "${data.aws_ami.hab-base-ami.id}"
  instance_type = "${var.smoke_janus_instance_type}"
  security_groups = [
    "${aws_security_group.janus.id}",
    "${data.terraform_remote_state.hab.hab_ring_security_group_id}",
  ]
  key_name = "${data.terraform_remote_state.base.mr_ssh_key_id}"
  iam_instance_profile = "${aws_iam_instance_profile.janus.id}"
  associate_public_ip_address = true
  lifecycle { create_before_destroy = true }
  root_block_device { volume_size = 128 }
  user_data = <<EOF
#!/usr/bin/env bash
while ! nc -z localhost 9632 ; do sleep 1; done
systemctl restart systemd-sysctl.service
# Forward port 8080 to 80, 8443 to 443 for janus websockets
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443

sudo mkdir -p /hab/user/janus-gateway/config

sudo cat > /hab/user/janus-gateway/config/user.toml << EOTOML
[nat]
nat_1_1_mapping = "$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"

[transports.http]
admin_ip = "$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
EOTOML

sudo sed -i "s/#RateLimitBurst=1000/RateLimitBurst=5000/" /etc/systemd/journald.conf
sudo systemctl restart systemd-journald

sudo /usr/bin/hab svc load mozillareality/janus-gateway --strategy at-once --url https://bldr.habitat.sh --channel unstable
sudo /usr/bin/hab svc load mozillareality/dd-agent --strategy at-once --url https://bldr.habitat.sh --channel stable
sudo /usr/bin/python /usr/bin/save_service_files janus-gateway default mozillareality
EOF
}
