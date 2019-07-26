terragrunt = {
  terraform {
    source = "git::git@github.com:mozilla/mr-ops.git//terraform/modules/base-global"
  }

  include {
    path = "${find_in_parent_folders()}"
  }
}
