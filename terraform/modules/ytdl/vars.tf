variable "ytdl_instance_type" {
  description = "YT-DL server instance type"
}

variable "ytdl_dns_prefix" {
  description = "Prefix before domain for DNS entry"
}

variable "ytdl_http_port" {
  description = "YT-DL HTTP service listener port"
}

variable "min_ytdl_servers" {
  description = "Minimum number of YT-DL servers to run"
}

variable "max_ytdl_servers" {
  description = "Maximum number of YT-DL servers to run"
}

variable "ytdl_domain" {
  description = "Domain name being used for YT-DL server (ex reticulum.io)"
}

variable "ytdl_channel" {
  description = "Distribution channel for YT-DL servers"
}

variable "ytdl_restart_strategy" {
  description = "Habitat restart strategy for YT-DL"
}
