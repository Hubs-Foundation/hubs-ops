terragrunt = {
  terraform {
    source = "git::git@github.com:mozilla/mr-ops.git?ref=feature/terraform-ret//terraform/modules/ret"
  }

  include {
    path = "${find_in_parent_folders()}"
  }

  dependencies {
    paths = ["../vpc", "../base", "../bastion", "../hab"]
  }
}

ret_ami = "ami-20c1f140"
ret_instance_type = "m3.medium"
ret_http_port = 4000
ret_webrtc_port = 5000
min_ret_servers = 1
max_ret_servers = 1
