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
      bucket = "mr-prod.terraform"
      key = "${path_relative_to_include()}/terraform.tfstate"
      region = "us-west-1"
      encrypt = true
      dynamodb_table = "mr-prod-terraform-lock"
    }
  }
}

shared = {
  region = "us-west-1"
  account_id = "558986605633"
  env = "prod"
  azs = "us-west-1a,us-west-1b"
  state_bucket = "mr-prod.terraform"
  dynamodb_table = "mr-prod-terraform-lock"
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
          "Action": "ec2:DescribeTags",
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
  lambda_role_policy = <<EOF
{

    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF
}
