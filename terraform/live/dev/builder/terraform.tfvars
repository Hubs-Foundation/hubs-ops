terragrunt = {
  terraform {
    source = "git::git@github.com:mozilla/mr-ops.git//terraform/modules/ci"
  }

  include {
    path = "${find_in_parent_folders()}"
  }

  dependencies {
    paths = ["../vpc", "../base", "../bastion"]
  }
}

enabled = true
builder_instance_type = "c4.2xlarge"
builder_domain = "reticulum.io"
