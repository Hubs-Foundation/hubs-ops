variable "shared" { type = "map" }
terraform { backend "s3" {} }
provider "aws" { region = "${var.shared["region"]}", version = "~> 0.1" }

resource "aws_key_pair" "mr-ssh-key" {
  key_name = "${var.shared["env"]}-mr-ssh-key"
  public_key = "${var.ssh_public_key}"
}
