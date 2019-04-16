variable "enabled" {
  description = "Should create resources in this module"
}

variable "bots_crowd_instance_type" {
  description = "Bot server instance type"
}

variable "min_bots_crowd_servers" {
  description = "Minimum number of Bot servers to run"
}

variable "max_bots_crowd_servers" {
  description = "Maximum number of Bot servers to run"
}
