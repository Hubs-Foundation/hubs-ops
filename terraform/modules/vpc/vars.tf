variable "cidr" {
  description = "CIDR for VPC"
}

variable "public_ranges" {
  description = "Comma separated public CIDRs for VPC"
}

variable "private_ranges" {
  description = "Comma separated private CIDRs for VPC"
}
