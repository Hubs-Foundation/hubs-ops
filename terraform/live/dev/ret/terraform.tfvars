terragrunt = {
  terraform {
    source = "git::git@github.com:mozilla/mr-ops.git?ref=feature/terraform-ret//terraform/modules/ret"
  }

  include {
    path = "${find_in_parent_folders()}"
  }

  dependencies {
    paths = ["../vpc", "../keys"]
  }
}

ret_http_port = 4000
ret_webrtc_port = 5000
min_ret_servers = 0
max_ret_servers = 0
