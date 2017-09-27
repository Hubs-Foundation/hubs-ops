variable "ret_http_port" {
  description = "Reticulum HTTP service listener port"
  default = 4000
}

variable "ret_webrtc_port" {
  description = "Reticulum WebRTC service listener port"
  default = 5000
}

variable "min_ret_servers" {
  description = "Minimum number of reticulum servers to run"
}

variable "max_ret_servers" {
  description = "Maximum number of reticulum servers to run"
}
