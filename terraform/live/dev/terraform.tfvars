terragrunt = {
  terraform {
    extra_arguments "conditional_vars" {
      commands = ["apply", "plan", "import", "push", "refresh", "destroy"]

      required_var_files = [
        "${get_parent_tfvars_dir()}/terraform.tfvars"
      ]
    }
  }

  remote_state {
    backend = "s3"

    config {
      bucket = "mr-dev.terraform"
      key = "${path_relative_to_include()}/terraform.tfstate"
      region = "us-west-1"
      encrypt = true
      dynamodb_table = "mr-dev-terraform-lock"
    }
  }
}

shared = {
  region = "us-west-1"
  env = "dev"
  azs = "us-west-1a,us-west-1b"
  state_bucket = "mr-dev.terraform"
  dynamodb_table = "mr-dev-terraform-lock"
  base_policy = <<EOF
{

    "Version": "2012-10-17",
    "Statement": [
      {
          "Effect": "Allow",
          "Action": "ec2:DescribeInstances",
          "Resource": "*"
      },
      {
          "Effect": "Allow",
          "Action": "ec2:CreateTags",
          "Resource": "*"
      },
      {
          "Effect": "Allow",
          "Action": "route53:ChangeResourceRecordSets",
          "Resource": "arn:aws:route53:::hostedzone/Z26OTGLBBCAHK4"
      }
    ]
  }
  EOF
  ec2_role_policy = <<EOF
{

    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF
  db_monitoring_policy = <<EOF
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
