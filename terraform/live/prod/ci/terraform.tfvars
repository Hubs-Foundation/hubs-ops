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
ci_instance_type = "c4.2xlarge"
min_ci_servers = 0
max_ci_servers = 0
ret_domain = "reticulum.io"
