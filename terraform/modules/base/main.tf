# Provides shared, base resources

variable "shared" { type = "map" }
terraform { backend "s3" {} }
provider "aws" { region = "${var.shared["region"]}", version = "~> 0.1" }

resource "aws_key_pair" "mr-ssh-key" {
  key_name = "${var.shared["env"]}-mr-ssh-key"
  public_key = "${var.ssh_public_key}"
}

# Shared base policy for all nodes
resource "aws_iam_policy" "base-policy" {
  name = "${var.shared["env"]}-base-policy"
  policy = "${var.shared["base_policy"]}"
}

resource "random_id" "bucket-identifier" {
  byte_length = 8
}

# Logs bucket
resource "aws_s3_bucket" "logs-bucket" {
  bucket = "logs.reticulum-${var.shared["env"]}-${random_id.bucket-identifier.hex}"
  acl = "private"
}
