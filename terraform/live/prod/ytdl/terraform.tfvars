terragrunt = {
  terraform {
    source = "git::git@github.com:mozilla/mr-ops.git//terraform/modules/ytdl"
  }

  include {
    path = "${find_in_parent_folders()}"
  }

  dependencies {
    paths = ["../vpc", "../base", "../bastion", "../hab", "../ret"]
  }
}

ytdl_domain = "reticulum.io"
ytdl_instance_type = "m3.medium"
ytdl_dns_prefix = "ytdl."
ytdl_http_port = 8080
min_ytdl_servers = 2
max_ytdl_servers = 2
ytdl_restart_strategy = "at-once"
ytdl_channel = "stable"
