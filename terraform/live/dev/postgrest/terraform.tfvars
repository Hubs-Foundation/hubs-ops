terragrunt = {
  terraform {
    source = "git::git@github.com:mozilla/mr-ops.git//terraform/modules/postgrest"
  }

  include {
    path = "${find_in_parent_folders()}"
  }

  dependencies {
    paths = ["../vpc", "../base", "../bastion", "../hab", "../ret"]
  }
}

postgrest_domain = "reticulum.io"
postgrest_dns_prefix = "postgrest-dev."
postgrest_instance_type = "m3.medium"
postgrest_http_port = 3000
postgrest_restart_strategy = "at-once"
postgrest_channel = "stable"
