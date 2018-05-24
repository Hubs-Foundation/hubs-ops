terragrunt = {
  terraform {
    source = "git::git@github.com:mozilla/hubs-ops.git//terraform/modules/coturn"
  }

  include {
    path = "${find_in_parent_folders()}"
  }

  dependencies {
    paths = ["../vpc", "../base", "../bastion"]
  }
}

enabled = true
coturn_instance_type = "m5.large"
min_coturn_servers = 1
max_coturn_servers = 1
