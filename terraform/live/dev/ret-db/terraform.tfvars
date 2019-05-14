terragrunt = {
  terraform {
    source = "git::git@github.com:mozilla/mr-ops.git//terraform/modules/ret-db"
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
dw_instance_class = "db.t3.medium"

