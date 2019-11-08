output "ret_target_group_ids" {
  value = "${aws_alb_target_group.ret-ssl.*.arn}"
}

output "ret_security_group_id" {
  value = "${aws_security_group.ret.id}"
}

output "ret_alb_id" {
  value = "${aws_alb.ret.id}"
}

output "ret_upload_backup_bucket_id" {
  value = "${aws_s3_bucket.upload-backup-bucket.id}"
}

output "ret_upload_backup_bucket_policy_arn" {
  value = "${aws_iam_policy.ret-upload-backup-policy.arn}"
}

output "ret_upload_mount_target_dns_name" {
  value = "${aws_efs_mount_target.uploads-fs.0.dns_name}"
}

output "ret_upload_fs_security_group_id" {
  value = "${aws_security_group.upload-fs.id}"
}

output "ret_upload_fs_connect_security_group_id" {
  value = "${aws_security_group.upload-fs-connect.id}"
}

output "polycosm_assets_bucket_id" {
  value ="${aws_s3_bucket.polycosm-assets-bucket.id}"
}

output "polycosm_assets_bucket_region" {
  value ="${var.shared["region"]}"
}
