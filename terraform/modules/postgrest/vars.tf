variable "postgrest_instance_type" {
  description = "PostgREST server instance type"
}

variable "postgrest_http_port" {
  description = "PostgREST HTTP service listener port"
}

variable "postgrest_channel" {
  description = "Distribution channel for PostgREST servers"
}

variable "postgrest_restart_strategy" {
  description = "Habitat restart strategy for PostgREST"
}

variable "postgrest_domain" {
  description = "Domain name being used for PostgREST server (ex reticulum.io)"
}

variable "postgrest_dns_prefix" {
  description = "Prefix before domain for DNS entry"
}


