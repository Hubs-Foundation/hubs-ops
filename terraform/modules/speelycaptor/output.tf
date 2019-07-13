output "speelycaptor-vpc-id" {
  value = "${data.terraform_remote_state.vpc.vpc_id}"
}

output "speelycaptor-subnet-ids" {
  value = "${data.terraform_remote_state.vpc.private_subnet_ids}"
}

output "speelycaptor-bucket-id" {
  value = "${aws_s3_bucket.speelycaptor-bucket.id}"
}

output "speelycaptor-public-bucket-id" {
  value = "${element(concat(aws_s3_bucket.speelycaptor-public-bucket.*.id, list("")),0)}"
}

output "speelycaptor-scratch-bucket-id" {
  value = "${aws_s3_bucket.speelycaptor-scratch-bucket.*.id[0]}"
}

output "speelycaptor-public-scratch-bucket-id" {
  value = "${element(concat(aws_s3_bucket.speelycaptor-public-scratch-bucket.*.id, list("")),0)}"
}

output "speelycaptor-iam-role" {
  value = "${aws_iam_role.speelycaptor-iam-role.*.arn[0]}"
}

output "speelycaptor-public-iam-role" {
  value = "${element(concat(aws_iam_role.speelycaptor-public-iam-role.*.arn, list("")),0)}"
}

output "speelycaptor-security-group" {
  value = "${aws_security_group.speelycaptor.id}"
}

output "speelycaptor-account-id" {
  value = "${var.shared["account_id"]}"
}

output "speelycaptor-region" {
  value = "${var.shared["region"]}"
}

output "ffmpeg-lambda-layer-arn" {
  value = "${data.aws_lambda_layer_version.ffmpeg.arn}"
}
