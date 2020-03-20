output "botomatic-vpc-id" {
  value = "${data.terraform_remote_state.vpc.vpc_id}"
}

output "botomatic-subnet-ids" {
  value = "${data.terraform_remote_state.vpc.private_subnet_ids}"
}

output "botomatic-iam-role" {
  value = "${aws_iam_role.botomatic-iam-role.*.arn[0]}"
}

output "botomatic-security-group" {
  value = "${aws_security_group.botomatic.id}"
}

output "botomatic-account-id" {
  value = "${var.shared["account_id"]}"
}

output "botomatic-region" {
  value = "${var.shared["region"]}"
}
