terragrunt = {
  terraform {
    source = "git::git@github.com:mozilla/mr-ops.git//terraform/modules/janus"
  }

  include {
    path = "${find_in_parent_folders()}"
  }

  dependencies {
    paths = ["../vpc", "../base", "../bastion", "../hab"]
  }
}

janus_instance_type = "m3.medium"
smoke_janus_instance_type = "m3.medium"
janus_wss_port = 443
janus_https_port = 8443
janus_admin_port = 7000
janus_rtp_port_from = 20000
janus_rtp_port_to = 60000
janus_channel = "stable"
janus_restart_strategy = "at-once"
