terragrunt = {
  terraform {
    source = "git::git@github.com:mozilla/mr-ops.git?ref=feature/terraform-ret//terraform/modules/hab"
  }

  include {
    path = "${find_in_parent_folders()}"
  }

  dependencies {
    paths = ["../vpc", "../base", "../bastion"]
  }
}

hab_ami = "ami-9ddaeafd"
hab_instance_type = "m3.medium"
min_hab_servers = 1
max_hab_servers = 1
