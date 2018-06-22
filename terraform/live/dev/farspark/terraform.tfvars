terragrunt = {
  terraform {
    source = "git::git@github.com:mozilla/mr-ops.git//terraform/modules/farspark"
  }

  include {
    path = "${find_in_parent_folders()}"
  }

  dependencies {
    paths = ["../vpc", "../base", "../bastion", "../hab"]
  }
}

farspark_domain = "reticulum.io"
farspark_instance_type = "m3.medium"
farspark_dns_prefix = "farspark-dev."
farspark_http_port = 8080
min_farspark_servers = 1
max_farspark_servers = 1
farspark_restart_strategy = "at-once"
farspark_channel = "stable"
