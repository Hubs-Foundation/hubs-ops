variable "instance_class" {
  description = "ret db server instance type"
}

variable "allocated_storage" {
  description = "Storage for DB in GB"
}

variable "password" {
  description = "Password for database admin. This can be found in an encrypted ansible vault vars/db.yml file."
}

variable "storage_type" {
  description = "Storage type to use"
}

