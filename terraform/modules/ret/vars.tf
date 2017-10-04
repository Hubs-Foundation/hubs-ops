variable "ret_ami" {
  description = "Reticulum server AMI"
}

variable "ret_instance_type" {
  description = "Reticulum server instance type"
}

variable "ret_http_port" {
  description = "Reticulum HTTP service listener port"
  default = 4000
}

variable "janus_ws_port" {
  description = "Janus signalling Websockets port"
  default = 6000
}

variable "janus_admin_port" {
  description = "Janus HTTP admin port"
  default = 7000
}

variable "janus_rtp_port_from" {
  description = "Janus RTP port from"
  default = 20000
}

variable "janus_rtp_port_to" {
  description = "Janus RTP port to"
  default = 60000
}

variable "min_ret_servers" {
  description = "Minimum number of reticulum servers to run"
}

variable "max_ret_servers" {
  description = "Maximum number of reticulum servers to run"
}
