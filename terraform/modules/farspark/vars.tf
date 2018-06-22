variable "farspark_instance_type" {
  description = "Farspark server instance type"
}

variable "farspark_dns_prefix" {
  description = "Prefix before domain for DNS entry"
}

variable "farspark_http_port" {
  description = "Farspark HTTP service listener port"
}

variable "min_farspark_servers" {
  description = "Minimum number of farspark servers to run"
}

variable "max_farspark_servers" {
  description = "Maximum number of farspark servers to run"
}

variable "farspark_domain" {
  description = "Domain name being used for farspark server (ex reticulum.io)"
}

variable "farspark_channel" {
  description = "Distribution channel for farspark servers"
}

variable "farspark_restart_strategy" {
  description = "Habitat restart strategy for farspark"
}
