variable "ret_instance_type" {
  description = "Reticulum server instance type"
}

variable "ret_http_port" {
  description = "Reticulum HTTP service listener port"
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
