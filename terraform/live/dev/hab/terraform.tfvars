terragrunt = {
  terraform {
    source = "git::git@github.com:mozilla/mr-ops.git?ref=feature/terraform-ret//terraform/modules/hab"
  }

  include {
    path = "${find_in_parent_folders()}"
  }

  dependencies {
    paths = ["../vpc", "../keys", "../bastion"]
  }
}

hab_ami = "ami-53e2d233"
hab_instance_type = "m3.medium"
min_hab_servers = 1
max_hab_servers = 1
