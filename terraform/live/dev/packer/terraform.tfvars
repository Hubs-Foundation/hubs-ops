terragrunt = {
  terraform {
    source = "git::git@github.com:mozilla/mr-ops.git?ref=feature/terraform-ret//terraform/modules/packer"
  }

  include {
    path = "${find_in_parent_folders()}"
  }
}
