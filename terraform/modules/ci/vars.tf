variable "ci_instance_type" {
  description = "ci server instance type"
}

variable "min_ci_servers" {
  description = "Minimum number of ci servers to run"
}

variable "max_ci_servers" {
  description = "Maximum number of ci servers to run"
}

variable "ret_domain" {
  description = "Domain name being used for reticulum server (ex reticulum.io)"
}

variable "enabled" {
  description = "Should create this module"
}
