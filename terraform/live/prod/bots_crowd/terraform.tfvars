terragrunt = {
  terraform {
    source = "git::git@github.com:mozilla/mr-ops.git//terraform/modules/bots_crowd"
  }

  include {
    path = "${find_in_parent_folders()}"
  }

  dependencies {
    paths = ["../vpc", "../base", "../bastion", "../hab", "../ret-db", "../ret"]
  }
}

enabled = false
bots_crowd_instance_type = "c4.xlarge"
min_bots_crowd_servers = 0
max_bots_crowd_servers = 0
