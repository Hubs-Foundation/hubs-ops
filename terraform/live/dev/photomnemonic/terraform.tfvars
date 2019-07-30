terragrunt = {
  terraform {
    source = "git::git@github.com:mozilla/mr-ops.git//terraform/modules/photomnemonic"
  }

  include {
    path = "${find_in_parent_folders()}"
  }

  dependencies {
    paths = ["../vpc", "../base", "../bastion", "../ret"]
  }
}

photomnemonic_domain = "reticulum.io"
photomnemonic_dns_prefix = "photomnemonic-dev."
photomnemonic_utils_dns_prefix = "photomnemonic-utils-dev."
enabled = true
