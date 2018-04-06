terragrunt = {
  terraform {
    source = "git::git@github.com:mozilla/mr-ops.git//terraform/modules/packer"
  }

  include {
    path = "${find_in_parent_folders()}"
  }
}
