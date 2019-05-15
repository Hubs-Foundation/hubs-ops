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
  description = "Password for database admin. This can be found in an encrypted ansible vault roles/migrate/vars/[dev|prod].yml file in the var db_password."
}

variable "dw_password" {
  description = "Password for DW database. This can be found in an encrypted ansible vault roles/migrate/vars/[dev|prod].yml file in the var dw_db_password."
}

variable "storage_type" {
  description = "Storage type to use"
}

