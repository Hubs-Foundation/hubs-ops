variable "instance_class" {
  description = "ret db server instance type"
}

variable "dw_instance_class" {
  description = "ret dw server instance type"
}

variable "allocated_storage" {
  description = "Storage for DB in GB"
}

variable "password" {
  description = "Password for database admin. This can be found in an encrypted ansible vault roles/ret/vars/[dev|prod].yml file."
}

variable "dw_password" {
  description = "Password for DW database. This can be found in an encrypted ansible vault roles/ret-db/vars/[dev|prod].yml file."
}

variable "storage_type" {
  description = "Storage type to use"
}

