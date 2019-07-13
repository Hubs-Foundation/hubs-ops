variable "speelycaptor_domain" {
  description = "DNS domain to use for speelycaptor"
}

variable "speelycaptor_dns_prefix" {
  description = "Prefix before domain for DNS entry"
}

variable "public_enabled" {
  description = "Should create resources in this module for the public lambda instance"
}

variable "enabled" {
  description = "Should create resources in this module"
}
