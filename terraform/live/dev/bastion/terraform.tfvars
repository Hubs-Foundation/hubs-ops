terragrunt = {
  terraform {
    source = "git::git@github.com:mozilla/mr-ops.git//terraform/modules/bastion"
  }

  include {
    path = "${find_in_parent_folders()}"
  }

  dependencies {
    paths = ["../vpc", "../base"]
  }
}

bastion_instance_type = "m3.medium"
min_bastion_servers = 1
max_bastion_servers = 1
