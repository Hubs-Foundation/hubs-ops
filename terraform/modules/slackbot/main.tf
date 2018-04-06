# Note: you will need to update the Lambda script with your own domain name
# and add encrypted `slackToken` and `jenkinsToken` environment variables via
# AWS console.

variable "shared" { type = "map" }
terraform { backend "s3" {} }
provider "aws" { region = "${var.shared["region"]}", version = "~> 0.1" }
provider "aws" { alias = "east", region = "us-east-1", version = "~> 0.1" }
data "aws_availability_zones" "all" {}

data "terraform_remote_state" "vpc" { backend = "s3", config = { key = "vpc/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }
data "terraform_remote_state" "base" { backend = "s3", config = { key = "base/terraform.tfstate", bucket = "${var.shared["state_bucket"]}", region = "${var.shared["region"]}", dynamodb_table = "${var.shared["dynamodb_table"]}", encrypt = "true" } }

resource "aws_iam_policy" "slackbot-policy" {
  name = "${var.shared["env"]}-slackbot-policy"
  count = "${var.enabled}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt"
      ],
      "Resource": "${data.terraform_remote_state.base.lambda_kms_key_arn}"
    }
  ]
}
EOF
}

resource "aws_iam_role" "mr-ops-command-slackbot-iam-role" {
  name = "${var.shared["env"]}-mr-ops-command-slackbot"
  assume_role_policy = "${var.shared["lambda_role_policy"]}"
  count = "${var.enabled}"
}

resource "aws_iam_role_policy_attachment" "lambda-sg-update-policy" {
  role = "${aws_iam_role.mr-ops-command-slackbot-iam-role.name}"
  policy_arn = "${aws_iam_policy.slackbot-policy.arn}"
  count = "${var.enabled}"
}

resource "aws_api_gateway_rest_api" "mr-ops-command-api" {
  provider = "aws.east"
  name = "mr-ops-command-api"
  count = "${var.enabled}"
}

resource "aws_api_gateway_resource" "mr-ops-command-resource" {
  provider = "aws.east"
  path_part = "mr-ops-command"
  parent_id = "${aws_api_gateway_rest_api.mr-ops-command-api.root_resource_id}"
  rest_api_id = "${aws_api_gateway_rest_api.mr-ops-command-api.id}"
  count = "${var.enabled}"
}

resource "aws_api_gateway_method" "mr-ops-command-method" {
  provider = "aws.east"
  rest_api_id   = "${aws_api_gateway_rest_api.mr-ops-command-api.id}"
  resource_id   = "${aws_api_gateway_resource.mr-ops-command-resource.id}"
  http_method   = "POST"
  authorization = "NONE"
  count = "${var.enabled}"
}

resource "aws_api_gateway_integration" "mr-ops-command-integration" {
  provider = "aws.east"
  rest_api_id             = "${aws_api_gateway_rest_api.mr-ops-command-api.id}"
  resource_id             = "${aws_api_gateway_resource.mr-ops-command-resource.id}"
  http_method             = "${aws_api_gateway_method.mr-ops-command-method.http_method}"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"

  request_templates = {
    "application/x-www-form-urlencoded" = "{ \"body\" : $input.json('$') }"
  }

  uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/${aws_lambda_function.mr-ops-command-slackbot.arn}/invocations"
  count = "${var.enabled}"
}

resource "aws_api_gateway_deployment" "mr-ops-command-deploy-prod" {
  provider = "aws.east"
  depends_on = ["aws_api_gateway_integration.mr-ops-command-integration"]
  rest_api_id = "${aws_api_gateway_rest_api.mr-ops-command-api.id}"
  stage_name = "prod"
  count = "${var.enabled}"
}

resource "aws_lambda_function" "mr-ops-command-slackbot" {
  provider = "aws.east"
  filename         = "mr-ops-command-slackbot.zip"
  function_name    = "mr-ops-command-slackbot"
  role             = "${aws_iam_role.mr-ops-command-slackbot-iam-role.arn}"
  handler          = "main.handler"
  source_code_hash = "${base64sha256(file("mr-ops-command-slackbot.zip"))}"
  runtime          = "nodejs4.3"
  timeout = 15
  kms_key_arn = "${data.terraform_remote_state.base.lambda_kms_key_arn}"
  count = "${var.enabled}"
}

resource "aws_lambda_permission" "mr-ops-lambda-permission" {
  provider = "aws.east"
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.mr-ops-command-slackbot.function_name}"
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:us-east-1:${var.shared["account_id"]}:${aws_api_gateway_rest_api.mr-ops-command-api.id}/*/${aws_api_gateway_method.mr-ops-command-method.http_method}${aws_api_gateway_resource.mr-ops-command-resource.path}"
  count = "${var.enabled}"
}

