terragrunt = {
  terraform {
    source = "git::git@github.com:mozilla/mr-ops.git//terraform/modules/drummon"
  }

  include {
    path = "${find_in_parent_folders()}"
  }

  dependencies {
    paths = ["../vpc", "../base", "../bastion", "../ret", "../photomnemonic"]
  }
}

drummon_domain = "reticulum.io"
drummon_dns_prefix = "drummon-dev."
enabled = true
