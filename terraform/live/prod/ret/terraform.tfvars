terragrunt = {
  terraform {
    source = "git::git@github.com:mozilla/mr-ops.git//terraform/modules/ret"
  }

  include {
    path = "${find_in_parent_folders()}"
  }

  dependencies {
    paths = ["../vpc", "../base", "../bastion", "../hab", "../ret-db"]
  }
}

ret_domain = "reticulum.io"
ret_instance_type = "m4.large"
ret_http_port = 4000
janus_wss_port = 443
janus_https_port = 8443
janus_admin_port = 7000
janus_rtp_port_from = 20000
janus_rtp_port_to = 60000
min_ret_servers = 3
max_ret_servers = 3
reticulum_channel = "stable"
reticulum_restart_strategy = "at-once"
public_domain_enabled = true
public_domain = "hubs.social"
