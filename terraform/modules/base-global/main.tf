# Provides shared, base resources across regions that have capabilities for services eg require AWS backup:

terraform { backend "s3" {} }
variable "shared" { type = "map" }
provider "aws" { alias = "us-west-1", region = "us-west-1", version = "~> 2.0" }
provider "aws" { alias = "us-west-2", region = "us-west-2", version = "~> 2.0" }
provider "aws" { alias = "us-east-1", region = "us-east-1", version = "~> 2.0" }
provider "aws" { alias = "us-east-2", region = "us-east-2", version = "~> 2.0" }
provider "aws" { alias = "eu-west-1", region = "eu-west-1", version = "~> 2.0" }
provider "aws" { alias = "ca-central-1", region = "ca-central-1", version = "~> 2.0" }
provider "aws" { alias = "ap-northeast-2", region = "ap-northeast-2", version = "~> 2.0" }
provider "aws" { alias = "ap-southeast-1", region = "ap-southeast-1", version = "~> 2.0" }
provider "aws" { alias = "ap-southeast-2", region = "ap-southeast-2", version = "~> 2.0" }
provider "aws" { alias = "ap-northeast-1", region = "ap-northeast-1", version = "~> 2.0" }
provider "aws" { alias = "eu-central-1", region = "eu-central-1", version = "~> 2.0" }

module "us-west-1" {
  source = "./module"
  region = "us-west-1"
  env = "${var.shared["env"]}"
  providers { aws = "aws.us-west-1" }
}

module "us-west-2" {
  source = "./module"
  region = "us-west-2"
  env = "${var.shared["env"]}"
  providers { aws = "aws.us-west-2" }
}

module "us-east-1" {
  source = "./module"
  region = "us-east-1"
  env = "${var.shared["env"]}"
  providers { aws = "aws.us-east-1" }
}

module "us-east-2" {
  source = "./module"
  region = "us-east-2"
  env = "${var.shared["env"]}"
  providers { aws = "aws.us-east-2" }
}

module "ap-northeast-2" {
  source = "./module"
  region = "ap-northeast-2"
  env = "${var.shared["env"]}"
  providers { aws = "aws.ap-northeast-2" }
}

module "ap-southeast-1" {
  source = "./module"
  region = "ap-southeast-1"
  env = "${var.shared["env"]}"
  providers { aws = "aws.ap-southeast-1" }
}

module "ap-southeast-2" {
  source = "./module"
  region = "ap-southeast-2"
  env = "${var.shared["env"]}"
  providers { aws = "aws.ap-southeast-2" }
}

module "ap-northeast-1" {
  source = "./module"
  region = "ap-northeast-1"
  env = "${var.shared["env"]}"
  providers { aws = "aws.ap-northeast-1" }
}

module "ca-central-1" {
  source = "./module"
  region = "ca-central-1"
  env = "${var.shared["env"]}"
  providers { aws = "aws.ca-central-1" }
}

module "eu-central-1" {
  source = "./module"
  region = "eu-central-1"
  env = "${var.shared["env"]}"
  providers { aws = "aws.eu-central-1" }
}

module "eu-west-1" {
  source = "./module"
  region = "eu-west-1"
  env = "${var.shared["env"]}"
  providers { aws = "aws.eu-west-1" }
}
