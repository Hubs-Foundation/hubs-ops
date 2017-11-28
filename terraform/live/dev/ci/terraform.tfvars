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

ci_instance_type = "c4.large"
min_ci_servers = 1
max_ci_servers = 1
