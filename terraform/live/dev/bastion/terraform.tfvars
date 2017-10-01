terragrunt = {
  terraform {
    source = "git::git@github.com:mozilla/mr-ops.git?ref=feature/terraform-ret//terraform/modules/bastion"
  }

  include {
    path = "${find_in_parent_folders()}"
  }

  dependencies {
    paths = ["../vpc", "../keys"]
  }
}

bastion_ami = "ami-ece1d18c"
bastion_instance_type = "m3.medium"
min_bastion_servers = 1
max_bastion_servers = 1
