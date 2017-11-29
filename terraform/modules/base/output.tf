output "base_policy_arn" {
  value = "${aws_iam_policy.base-policy.arn}"
}

output "mr_ssh_key_id" {
  value = "${aws_key_pair.mr-ssh-key.id}"
}

output "logs_bucket_id" {
  value ="${aws_s3_bucket.logs-bucket.id}"
}

output "backups_bucket_id" {
  value ="${aws_s3_bucket.backups-bucket.id}"
}

output "builds_bucket_id" {
  value ="${aws_s3_bucket.builds-bucket.id}"
}
