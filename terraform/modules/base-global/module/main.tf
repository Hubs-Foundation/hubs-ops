variable "region" {}
variable "env" {}

resource "random_id" "bucket-identifier" {
  byte_length = 8
}

