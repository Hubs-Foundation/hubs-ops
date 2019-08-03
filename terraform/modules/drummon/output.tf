output "drummon-vpc-id" {
  value = "${data.terraform_remote_state.vpc.vpc_id}"
}

output "drummon-vpc-endpoint-dns" {
  value = "${data.terraform_remote_state.photomnemonic.vpc-endpoint-dns}"
}

output "drummon-subnet-ids" {
  value = "${data.terraform_remote_state.vpc.private_subnet_ids}"
}

output "drummon-zone-id" {
  value = "${data.aws_route53_zone.drummon-zone.zone_id}"
}

output "drummon-domain" {
  value = "${var.drummon_domain}"
}

output "drummon-bucket-id" {
  value = "${aws_s3_bucket.drummon-bucket.*.id[0]}"
}

output "drummon-iam-role" {
  value = "${aws_iam_role.drummon-iam-role.*.arn[0]}"
}

output "drummon-security-group" {
  value = "${aws_security_group.drummon.*.id[0]}"
}

output "drummon-account-id" {
  value = "${var.shared["account_id"]}"
}

output "drummon-region" {
  value = "${var.shared["region"]}"
}

output "drummon-dns-prefix" {
  value = "${var.drummon_dns_prefix}"
}

output "drummon-cert-arn" {
  value = "${data.aws_acm_certificate.drummon-cert-east.arn}"
}
