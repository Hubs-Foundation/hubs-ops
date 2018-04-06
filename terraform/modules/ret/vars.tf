variable "ret_instance_type" {
  description = "Reticulum server instance type"
}

variable "ret_http_port" {
  description = "Reticulum HTTP service listener port"
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

variable "min_ret_servers" {
  description = "Minimum number of reticulum servers to run"
}

variable "max_ret_servers" {
  description = "Maximum number of reticulum servers to run"
}

variable "ret_domain" {
  description = "Domain name being used for reticulum server (ex reticulum.io)"
}

variable "janus_restart_strategy" {
  description = "Habitat restart strategy for Janus"
}

variable "reticulum_restart_strategy" {
  description = "Habitat restart strategy for Reticulum"
}
