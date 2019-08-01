output "nearspark-vpc-id" {
  value = "${data.terraform_remote_state.vpc.vpc_id}"
}

output "nearspark-vpc-endpoint-dns" {
  value = "${data.terraform_remote_state.photomnemonic.vpc-endpoint-dns}"
}

output "nearspark-subnet-ids" {
  value = "${data.terraform_remote_state.vpc.private_subnet_ids}"
}

output "nearspark-zone-id" {
  value = "${data.aws_route53_zone.nearspark-zone.zone_id}"
}

output "nearspark-domain" {
  value = "${var.nearspark_domain}"
}

output "nearspark-bucket-id" {
  value = "${aws_s3_bucket.nearspark-bucket.id}"
}

output "nearspark-iam-role" {
  value = "${aws_iam_role.nearspark-iam-role.*.arn[0]}"
}

output "nearspark-security-group" {
  value = "${aws_security_group.nearspark.id}"
}

output "nearspark-account-id" {
  value = "${var.shared["account_id"]}"
}

output "nearspark-region" {
  value = "${var.shared["region"]}"
}

output "nearspark-dns-prefix" {
  value = "${var.nearspark_dns_prefix}"
}

output "nearspark-cert-arn" {
  value = "${data.aws_acm_certificate.nearspark-cert-east.arn}"
}
