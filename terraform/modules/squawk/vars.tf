variable "enabled" {
  description = "Should create resources in this module"
}

variable "squawk_instance_type" {
  description = "Squawker server instance type"
}

variable "min_squawk_servers" {
  description = "Minimum number of squawk servers to run"
}

variable "max_squawk_servers" {
  description = "Maximum number of squawk servers to run"
}
