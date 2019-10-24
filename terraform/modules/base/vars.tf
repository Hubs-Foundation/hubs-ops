variable "ssh_public_key" {}

variable "link_redirector_domains" {
  description = "Domain names being used for link redirector"
  type = "list"
}

variable "link_redirector_enabled" {
  description = "If link redirector is enabled"
}

variable "link_redirector_target" {
  description = "Target URL to redirect to for link redirector"
}

variable "link_redirector_target_hostname" {
  description = "Target hostname to redirect to for link redirector"
}

variable "photos_redirector_domains" {
  description = "Domain names being used for photos redirector"
  type = "list"
}

variable "photos_redirector_enabled" {
  description = "If photos redirector is enabled"
}

variable "photos_redirector_target" {
  description = "Target URL to redirect to for photos redirector"
}

variable "photos_redirector_target_hostname" {
  description = "Target hostname to redirect to for photos redirector"
}

variable "root_redirector_domains" {
  description = "Domain names being used for root redirector"
  type = "list"
}

variable "root_redirector_enabled" {
  description = "If root redirector is enabled"
}

variable "root_redirector_target" {
  description = "Target URL to redirect to for root redirector"
}

variable "root_redirector_target_hostname" {
  description = "Target hostname to redirect to for root redirector"
}

variable "stack_create_redirector_domains" {
  description = "Domain names being used for stack create redirector"
  type = "list"
}

variable "stack_create_redirector_enabled" {
  description = "If stack create redirector is enabled"
}

variable "stack_create_redirector_target" {
  description = "Target URL to redirect to for stack create redirector"
}
