variable "enabled" {
  description = "Should create resources in this module"
}

variable "coturn_instance_type" {
  description = "coturn server instance type"
}

variable "min_coturn_servers" {
  description = "Minimum number of coturn servers to run"
}

variable "max_coturn_servers" {
  description = "Maximum number of coturn servers to run"
}
