variable "region" {}
variable "env" {}

resource "random_id" "bucket-identifier" {
  byte_length = 8
}

resource "aws_s3_bucket" "shared-layer" {
  bucket = "shared-layer.${var.region}-${var.env}.${random_id.bucket-identifier.hex}"
  acl = "public-read"
}

