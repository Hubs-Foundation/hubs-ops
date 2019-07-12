terragrunt = {
  terraform {
    source = "git::git@github.com:mozilla/mr-ops.git//terraform/modules/speelycaptor"
  }

  include {
    path = "${find_in_parent_folders()}"
  }

  dependencies {
    paths = ["../vpc", "../base", "../bastion", "../ret", "../photomnemonic"]
  }
}

speelycaptor_domain = "reticulum.io"
speelycaptor_dns_prefix = "speelycaptor-dev."
enabled = true
public_enabled = true
