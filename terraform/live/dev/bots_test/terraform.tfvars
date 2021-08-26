terragrunt = {
  terraform {
    source = "git::git@github.com:mozilla/mr-ops.git//terraform/modules/bots_smoke"
  }

  include {
    path = "${find_in_parent_folders()}"
  }

  dependencies {
    paths = ["../vpc", "../base", "../bastion", "../hab", "../ret-db", "../ret"]
  }
}

enabled = true
bots_smoke_instance_type = "c4.xlarge"
min_bots_smoke_servers = 5
max_bots_smoke_servers = 5
