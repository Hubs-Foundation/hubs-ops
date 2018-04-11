variable "janus_instance_type" {
  description = "Janus server instance type"
}

variable "smoke_janus_instance_type" {
  description = "Smoke Janus server instance type"
}

variable "janus_https_port" {
  description = "Janus signalling secure HTTP port"
}

variable "janus_wss_port" {
  description = "Janus signalling secure Websockets port"
}

variable "janus_admin_port" {
  description = "Janus HTTP admin port"
}

variable "janus_rtp_port_from" {
  description = "Janus RTP port from"
}

variable "janus_rtp_port_to" {
  description = "Janus RTP port to"
}

variable "janus_restart_strategy" {
  description = "Habitat restart strategy for Janus"
}
