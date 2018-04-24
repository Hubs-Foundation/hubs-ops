variable "ret_instance_type" {
  description = "Reticulum server instance type"
}

variable "ret_http_port" {
  description = "Reticulum HTTP service listener port"
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

variable "reticulum_channel" {
  description = "Distribution channel for reticulum on non-smoke servers"
}

variable "reticulum_restart_strategy" {
  description = "Habitat restart strategy for Reticulum"
}

variable "public_domain_enabled" {
  description = "Should bind to public domain (typically prod only)"
}

variable "public_domain" {
  description = "Domain to use for public access (ex yoursite.com)"
}
