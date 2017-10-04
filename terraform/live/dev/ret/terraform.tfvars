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

ret_ami = "ami-a57142c5"
ret_instance_type = "m3.medium"
ret_http_port = 4000
janus_ws_port = 6000 
janus_admin_port = 7000
janus_rtp_port_from = 20000
janus_rtp_port_to = 60000
min_ret_servers = 1
max_ret_servers = 1
