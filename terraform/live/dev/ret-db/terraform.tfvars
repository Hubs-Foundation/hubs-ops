terragrunt = {
  terraform {
    source = "git::git@github.com:mozilla/mr-ops.git?ref=feature/terraform-ret//terraform/modules/ret-db"
  }

  include {
    path = "${find_in_parent_folders()}"
  }

  dependencies {
    paths = ["../vpc", "../base"]
  }
}

instance_class = "db.m4.large"
allocated_storage = "100"
storage_type = "gp2"

