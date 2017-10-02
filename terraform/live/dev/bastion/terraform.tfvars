terragrunt = {
  terraform {
    source = "git::git@github.com:mozilla/mr-ops.git?ref=feature/terraform-ret//terraform/modules/bastion"
  }

  include {
    path = "${find_in_parent_folders()}"
  }

  dependencies {
    paths = ["../vpc", "../base"]
  }
}

bastion_ami = "ami-01d9e961"
bastion_instance_type = "m3.medium"
min_bastion_servers = 1
max_bastion_servers = 1
