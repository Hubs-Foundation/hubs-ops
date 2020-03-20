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

enabled = false
builder_instance_type = "c4.2xlarge"
builder_domain = "reticulum.io"
mount_target_count = 0
