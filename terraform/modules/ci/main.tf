variable "shared" { type = "map" }
terraform { backend "s3" {} }
provider "aws" { region = "${var.shared["region"]}", version = "~> 0.1" }
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
}

resource "aws_iam_role" "ci" {
  name = "${var.shared["env"]}-ci"
  assume_role_policy = "${var.shared["ec2_role_policy"]}"
}

resource "aws_iam_role_policy_attachment" "ci-base-policy" {
  role = "${aws_iam_role.ci.name}"
  policy_arn = "${data.terraform_remote_state.base.base_policy_arn}"
}

resource "aws_iam_role_policy_attachment" "ci-backup-s3-policy" {
  role = "${aws_iam_role.ci.name}"
  policy_arn = "${aws_iam_policy.ci-backup-s3-policy.arn}"
}

resource "aws_iam_policy" "ci-backup-s3-policy" {
  name = "${var.shared["env"]}-ci-backup-s3-policy"
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

resource "aws_iam_instance_profile" "ci" {
  name = "${var.shared["env"]}-ci"
  role = "${aws_iam_role.ci.id}"
}

resource "aws_launch_configuration" "ci" {
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
while ! [ -f /hab/sup/default/MEMBER_ID ] ; do sleep 1; done

# Jenkins needs to run hab docker studio as sudo
sudo echo '#!/usr/bin/env bash' > /usr/bin/hab-docker-studio
sudo echo 'hab studio -D $@' >> /usr/bin/hab-docker-studio
sudo chmod +x /usr/bin/hab-docker-studio
sudo echo "hab ALL=(ALL) NOPASSWD: /usr/bin/hab-docker-studio" >> /etc/sudoers

sudo apt-get install -y docker.io
sudo /usr/bin/hab start mozillareality/jenkins-war --strategy at-once --url https://bldr.habitat.sh --channel stable
EOF
}

resource "aws_autoscaling_group" "ci" {
  name = "${var.shared["env"]}-ci"
  launch_configuration = "${aws_launch_configuration.ci.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  vpc_zone_identifier = ["${data.terraform_remote_state.vpc.private_subnet_ids}"]

  min_size = "${var.min_ci_servers}"
  max_size = "${var.max_ci_servers}"

  lifecycle { create_before_destroy = true }
  tag { key = "env", value = "${var.shared["env"]}", propagate_at_launch = true }
  tag { key = "host-type", value = "${var.shared["env"]}-ci", propagate_at_launch = true }
  tag { key = "hab-ring", value = "${var.shared["env"]}", propagate_at_launch = true }
}
