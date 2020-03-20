terragrunt = {
  terraform {
    source = "git::git@github.com:mozilla/mr-ops.git//terraform/modules/botomatic"
  }

  include {
    path = "${find_in_parent_folders()}"
  }

  dependencies {
    paths = ["../vpc", "../base", "../bastion", "../ret", "../photomnemonic"]
  }
}

botomatic_domain = "reticulum.io"
botomatic_dns_prefix = "botomatic."
enabled = false
