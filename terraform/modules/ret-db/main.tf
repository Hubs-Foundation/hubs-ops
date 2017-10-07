variable "global" { type = "map" }
variable "shared" { type = "map" }
terraform { backend "s3" {} }
provider "aws" { region = "${var.shared["region"]}", version = "~> 0.1" }
data "aws_availability_zones" "all" {}

data "terraform_remote_state" "vpc" { backend = "s3", config = { key = "vpc/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "base" { backend = "s3", config = { key = "base/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }

resource "aws_security_group" "ret-db" {
  name = "${var.shared["env"]}-ret-db"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"

  ingress {
    from_port = "5432"
    to_port = "5432"
    protocol = "tcp"
    security_groups = ["${aws_security_group.ret-db-consumer.id}"]
  }
}

resource "aws_security_group" "ret-db-consumer" {
  name = "${var.shared["env"]}-ret-db-consumer"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"
}

resource "aws_security_group_rule" "ret-db-consumer-egress" {
  type = "egress"
  from_port = "5432"
  to_port = "5432"
  protocol = "tcp"
  security_group_id = "${aws_security_group.ret-db-consumer.id}"
  source_security_group_id = "${aws_security_group.ret-db.id}"
}

resource "aws_db_subnet_group" "ret-db-subnet-group" {
  name = "${var.shared["env"]}-ret-db-subnet-group"
  subnet_ids = ["${data.terraform_remote_state.vpc.private_subnet_ids}"]
}

resource "aws_iam_role" "ret-db-monitoring" {
  name = "${var.shared["env"]}-ret-db-monitoring"
  assume_role_policy = "${var.shared["ec2_role_policy"]}"
}

resource "aws_iam_role_policy" "ret-db-monitoring-policy" {
  role = "${aws_iam_role.ret-db-monitoring.name}"
  name = "${var.shared["env"]}-ret-db-monitoring-policy"
  policy = <<EOF
{
      "Version": "2012-10-17",
      "Statement": [
          {
              "Sid": "EnableCreationAndManagementOfRDSCloudwatchLogGroups",
              "Effect": "Allow",
              "Action": [
                  "logs:CreateLogGroup",
                  "logs:PutRetentionPolicy"
              ],
              "Resource": [
                  "arn:aws:logs:*:*:log-group:RDS*"
              ]
          },
          {
              "Sid": "EnableCreationAndManagementOfRDSCloudwatchLogStreams",
              "Effect": "Allow",
              "Action": [
                  "logs:CreateLogStream",
                  "logs:PutLogEvents",
                  "logs:DescribeLogStreams",
                  "logs:GetLogEvents"
              ],
              "Resource": [
                  "arn:aws:logs:*:*:log-group:RDS*:log-stream:*"
              ]
          }
      ]
  }
  EOF
}

resource "aws_db_parameter_group" "ret-db-parameter-group" {
  name = "${var.shared["env"]}-ret-db-parameter-group"
  family = "postgres9.6"
}

resource "aws_db_instance" "ret-db" {
  allocated_storage = "${var.allocated_storage}"
  apply_immediately = true
  backup_retention_period = 14
  backup_window = "09:30-10:00"
  db_subnet_group_name = "${aws_db_subnet_group.ret-db-subnet-group.id}"
  engine = "postgres"
  engine_version = "9.6"
  final_snapshot_identifier = "${var.shared["env"]}-ret-db-final"
  identifier_prefix = "${var.shared["env"]}-ret-db"
  instance_class = "${var.instance_class}"
  maintenance_window = "Sun:08:30-Sun:09:30"
  # TODO, this wasn't working yet, AWS complains about:
  # Instance: InvalidParameterValue: IAM role ARN value is invalid or does not include the required permissions for: ENHANCED_MONITORING
  # monitoring_interval = 30
  # monitoring_role_arn = "${aws_iam_role.ret-db-monitoring.arn}"
  multi_az = true
  name = "ret_production"
  parameter_group_name = "${aws_db_parameter_group.ret-db-parameter-group.name}"
  password = "${var.password}"
  port = 5432
  publicly_accessible = false
  storage_encrypted = false
  storage_type = "${var.storage_type}"
  username = "postgres"
  vpc_security_group_ids = ["${aws_security_group.ret-db.id}"]
}

