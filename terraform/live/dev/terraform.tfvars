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
  account_id = "558986605633"
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
          "Action": "ec2:DescribeTags",
          "Resource": "*"
      },
			{
          "Effect": "Allow",
          "Action": [
              "ssm:DescribeAssociation",
              "ssm:GetDeployablePatchSnapshotForInstance",
              "ssm:GetDocument",
              "ssm:DescribeDocument",
              "ssm:GetManifest",
              "ssm:GetParameters",
              "ssm:ListAssociations",
              "ssm:ListInstanceAssociations",
              "ssm:PutInventory",
              "ssm:PutComplianceItems",
              "ssm:PutConfigurePackageResult",
              "ssm:UpdateAssociationStatus",
              "ssm:UpdateInstanceAssociationStatus",
              "ssm:UpdateInstanceInformation"
          ],
          "Resource": "*"
      },
      {
          "Effect": "Allow",
          "Action": [
              "ssmmessages:CreateControlChannel",
              "ssmmessages:CreateDataChannel",
              "ssmmessages:OpenControlChannel",
              "ssmmessages:OpenDataChannel"
          ],
          "Resource": "*"
      },
      {
          "Effect": "Allow",
          "Action": [
              "ec2messages:AcknowledgeMessage",
              "ec2messages:DeleteMessage",
              "ec2messages:FailMessage",
              "ec2messages:GetEndpoint",
              "ec2messages:GetMessages",
              "ec2messages:SendReply"
          ],
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
