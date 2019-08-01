terragrunt = {
  terraform {
    source = "git::git@github.com:mozilla/mr-ops.git//terraform/modules/nearspark"
  }

  include {
    path = "${find_in_parent_folders()}"
  }

  dependencies {
    paths = ["../vpc", "../base", "../bastion", "../ret", "../photomnemonic"]
  }
}

nearspark_domain = "reticulum.io"
nearspark_dns_prefix = "nearspark-dev."
enabled = true
