variable "enabled" {
  description = "Should create resources in this module"
}

variable "bots_test_instance_type" {
  description = "Bot server instance type"
}

variable "min_bots_test_servers" {
  description = "Minimum number of Bot servers to run"
}

variable "max_bots_test_servers" {
  description = "Maximum number of Bot servers to run"
}
