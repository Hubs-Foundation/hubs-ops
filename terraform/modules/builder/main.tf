variable "shared" { type = "map" }
terraform { backend "s3" {} }
provider "aws" { region = "${var.shared["region"]}", version = "~> 2.0" }
provider "aws" { alias = "east", region = "us-east-1", version = "~> 2.0" }
data "aws_availability_zones" "all" {}

data "terraform_remote_state" "vpc" { backend = "s3", config = { key = "vpc/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "base" { backend = "s3", config = { key = "base/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "bastion" { backend = "s3", config = { key = "bastion/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "hab" { backend = "s3", config = { key = "hab/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }

data "aws_route53_zone" "reticulum-zone" {
  name = "${var.builder_domain}."
}

data "aws_acm_certificate" "builder-alb-listener-cert" {
  domain = "*.${var.builder_domain}"
  statuses = ["ISSUED"]
  most_recent = true
}

data "aws_acm_certificate" "builder-cert-east" {
  provider = "aws.east"
  domain = "*.${var.builder_domain}"
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

resource "aws_security_group" "builder-alb" {
  count = "${var.enabled}"
  name = "${var.shared["env"]}-builder-alb"
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

resource "aws_security_group_rule" "builder-alb-egress-ssl" {
  count = "${var.enabled}"
  type = "egress"
  from_port = "80"
  to_port = "80"
  protocol = "tcp"
  security_group_id = "${aws_security_group.builder-alb.id}"
  source_security_group_id = "${aws_security_group.builder.id}"
}

resource "aws_route53_record" "builder-alb-dns" {
  count = "${var.enabled}"
  zone_id = "${data.aws_route53_zone.reticulum-zone.zone_id}"
  name = "${var.shared["env"]}-builder.${data.aws_route53_zone.reticulum-zone.name}"
  type = "A"

  alias {
    name = "${aws_alb.builder-alb.dns_name}"
    zone_id = "${aws_alb.builder-alb.zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_alb" "builder-alb" {
  count = "${var.enabled}"
  name = "${var.shared["env"]}-builder"
  security_groups = ["${aws_security_group.builder-alb.id}"]
  subnets = ["${data.terraform_remote_state.vpc.public_subnet_ids}"]

  lifecycle { create_before_destroy = true }
}

resource "aws_alb_target_group" "builder-alb-group-http" {
  count = "${var.enabled}"
  name = "${var.shared["env"]}-builder-alb-group-http"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"
  port = "80"
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

resource "aws_alb_listener" "builder-ssl-alb-listener" {
  count = "${var.enabled}"
  load_balancer_arn = "${aws_alb.builder-alb.arn}"
  port = 443

  protocol = "HTTPS"
  ssl_policy = "ELBSecurityPolicy-2015-05"

  certificate_arn = "${data.aws_acm_certificate.builder-alb-listener-cert.arn}"

  default_action {
    target_group_arn = "${aws_alb_target_group.builder-alb-group-http.arn}"
    type = "forward"
  }
}

resource "aws_security_group" "builder" {
  count = "${var.enabled}"
  name = "${var.shared["env"]}-builder"
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

  # HTTP
  ingress {
    from_port = "80"
    to_port = "80"
    protocol = "tcp"
    security_groups = ["${aws_security_group.builder-alb.id}"]
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

  # NFS upload-fs
  egress {
    from_port = "2049"
    to_port = "2049"
    protocol = "tcp"
    security_groups = ["${aws_security_group.builder-hab-fs.id}"]
  }
}

resource "aws_efs_file_system" "builder-hab-fs" {
  count = "${var.enabled}"
  creation_token = "${var.shared["env"]}-builder-hab-fs"
  performance_mode = "generalPurpose"
  tags = {
    backup = "builder-hab-daily"
  }
}

resource "aws_kms_key" "builder-daily-backup-key" {
  count = "${var.enabled}"
  description = "Encryption key for builder hab storage backups"
  enable_key_rotation = true
  is_enabled = true
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Action": "kms:*",
        "Principal": { "AWS": "arn:aws:iam::${var.shared["account_id"]}:root" },
        "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_backup_vault" "builder-hab-daily-backup-vault" {
  count = "${var.enabled}"
  name = "${var.shared["env"]}-builder-hab-daily-backup"
  kms_key_arn = "${aws_kms_key.builder-daily-backup-key.arn}"
}

resource "aws_backup_plan" "builder-hab-daily-backup-plan" {
  count = "${var.enabled}"
  name = "${var.shared["env"]}-builder-hab-daily-backup-plan"

  rule {
    rule_name = "daily"
    target_vault_name = "${aws_backup_vault.builder-hab-daily-backup-vault.name}"
    schedule = "cron(0 10 ? * * *)"
  }
}

resource "aws_iam_role" "builder-hab-daily-backup-role" {
  count = "${var.enabled}"
  name = "${var.shared["env"]}-builder-hab-daily-backup"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Principal": { "Service": [ "backup.amazonaws.com" ] },
        "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "builder-hab-daily-backup-aws-backup-policy" {
  count = "${var.enabled}"
  role = "${aws_iam_role.builder-hab-daily-backup-role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_backup_selection" "builder-hab-daily-backup-selection" {
  count = "${var.enabled}"
  iam_role_arn = "${aws_iam_role.builder-hab-daily-backup-role.arn}"
  name = "${var.shared["env"]}-builder-hab-daily-backup-selection"
  plan_id = "${aws_backup_plan.builder-hab-daily-backup-plan.id}"

  selection_tag {
    type = "STRINGEQUALS"
    key = "backup"
    value = "builder-hab-daily"
  }

  depends_on = ["aws_iam_role_policy_attachment.builder-hab-daily-backup-aws-backup-policy"]
}

resource "aws_efs_mount_target" "builder-hab-fs" {
  count = "${var.enabled}"
  file_system_id = "${aws_efs_file_system.builder-hab-fs.id}"
  subnet_id = "${element(data.terraform_remote_state.vpc.private_subnet_ids, count.index)}"
  security_groups = ["${aws_security_group.builder-hab-fs.id}"]
  count = "${length(data.terraform_remote_state.vpc.private_subnet_ids)}"
}

resource "aws_security_group" "builder-hab-fs" {
  count = "${var.enabled}"
  name = "${var.shared["env"]}-builder-hab-fs"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"
}

resource "aws_security_group" "builder-hab-fs-connect" {
  count = "${var.enabled}"
  name = "${var.shared["env"]}-builder-hab-fs-connect"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"
}

resource "aws_security_group_rule" "builder-builder-hab-fs-builder-ingress" {
  count = "${var.enabled}"
  type = "ingress"
  from_port = "2049"
  to_port = "2049"
  protocol = "tcp"
  security_group_id = "${aws_security_group.builder-hab-fs.id}"
  source_security_group_id = "${aws_security_group.builder.id}"
}

resource "aws_security_group_rule" "builder-builder-hab-fs-connect-ingress" {
  count = "${var.enabled}"
  type = "ingress"
  from_port = "2049"
  to_port = "2049"
  protocol = "tcp"
  security_group_id = "${aws_security_group.builder-hab-fs.id}"
  source_security_group_id = "${aws_security_group.builder-hab-fs-connect.id}"
}

resource "aws_iam_role" "builder" {
  count = "${var.enabled}"
  name = "${var.shared["env"]}-builder"
  assume_role_policy = "${var.shared["ec2_role_policy"]}"
}

resource "aws_iam_role_policy_attachment" "builder-base-policy" {
  count = "${var.enabled}"
  role = "${aws_iam_role.builder.name}"
  policy_arn = "${data.terraform_remote_state.base.base_policy_arn}"
}

resource "aws_iam_instance_profile" "builder" {
  count = "${var.enabled}"
  name = "${var.shared["env"]}-builder"
  role = "${aws_iam_role.builder.id}"
}

resource "aws_launch_configuration" "builder" {
  count = "${var.enabled}"
  image_id = "${data.aws_ami.hab-base-ami.id}"
  instance_type = "${var.builder_instance_type}"
  security_groups = [
    "${aws_security_group.builder.id}",
    "${data.terraform_remote_state.hab.hab_ring_security_group_id}",
  ]
  key_name = "${data.terraform_remote_state.base.mr_ssh_key_id}"
  iam_instance_profile = "${aws_iam_instance_profile.builder.id}"
  associate_public_ip_address = false
  lifecycle { create_before_destroy = true }
  root_block_device { volume_size = 64 }
  user_data = <<EOF
#!/usr/bin/env bash
while ! nc -z localhost 9632 ; do sleep 1; done
systemctl restart systemd-sysctl.service

rm -rf /hab
sudo mkdir /hab
sudo echo "${aws_efs_mount_target.builder-hab-fs.0.dns_name}:/       /hab        nfs     nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=3,noresvport" >> /etc/fstab
sudo mount /hab
sudo chown hab:hab /hab

EOF
}

resource "aws_autoscaling_group" "builder" {
  count = "${var.enabled}"
  name = "${var.shared["env"]}-builder"
  launch_configuration = "${aws_launch_configuration.builder.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  vpc_zone_identifier = ["${data.terraform_remote_state.vpc.private_subnet_ids}"]

  min_size = "1"
  max_size = "1"

  target_group_arns = ["${aws_alb_target_group.builder-alb-group-http.arn}"]

  lifecycle { create_before_destroy = true }
  tag { key = "env", value = "${var.shared["env"]}", propagate_at_launch = true }
  tag { key = "host-type", value = "${var.shared["env"]}-builder", propagate_at_launch = true }
  tag { key = "hab-ring", value = "${var.shared["env"]}", propagate_at_launch = true }
}

