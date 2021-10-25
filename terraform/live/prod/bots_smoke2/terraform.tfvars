terragrunt = {
  terraform {
    source = "git::git@github.com:mozilla/mr-ops.git//terraform/modules/bots_smoke2"
  }

  include {
    path = "${find_in_parent_folders()}"
  }

  dependencies {
    paths = ["../vpc", "../base", "../bastion", "../hab", "../ret-db", "../ret"]
  }
}

enabled = true
bots_smoke2_instance_type = "c4.xlarge"
min_bots_smoke2_servers = 1
max_bots_smoke2_servers = 1
