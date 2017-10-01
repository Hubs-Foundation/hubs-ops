terragrunt = {
  terraform {
    source = "git::git@github.com:mozilla/mr-ops.git?ref=feature/terraform-ret//terraform/modules/vpc"
  }

  include {
    path = "${find_in_parent_folders()}"
  }
}

cidr = "10.32.0.0/16"
public_ranges = "10.32.0.0/24,10.32.2.0/24"
private_ranges = "10.32.1.0/24,10.32.3.0/24"
