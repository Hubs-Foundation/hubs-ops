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

output "assets_bucket_id" {
  value ="${aws_s3_bucket.assets-bucket.id}"
}

output "assets_bucket_domain_name" {
  value ="${aws_s3_bucket.assets-bucket.bucket_domain_name}"
}

output "asset_bundles_bucket_id" {
  value ="${aws_s3_bucket.asset-bundles-bucket.id}"
}

output "asset_bundles_bucket_domain_name" {
  value ="${aws_s3_bucket.asset-bundles-bucket.bucket_domain_name}"
}

output "cloudfront_http_security_group_id" {
  value ="${aws_security_group.cloudfront-http.id}"
}

output "cloudfront_https_security_group_id" {
  value ="${aws_security_group.cloudfront-https.id}"
}

output "lambda_kms_key_arn" {
  value ="${aws_kms_key.lambda-kms-key.arn}"
}

output "lambda_kms_key_key_id" {
  value ="${aws_kms_key.lambda-kms-key.key_id}"
}

output "timecheck_bucket_website_endpoint" {
  value ="${aws_s3_bucket.timecheck-bucket.website_endpoint}"
}

output "link_redirector_website_endpoint" {
  value ="${aws_s3_bucket.link-redirector-bucket.website_endpoint}"
}

output "root_redirector_website_endpoint" {
  value ="${aws_s3_bucket.root-redirector-bucket.website_endpoint}"
}

output "polycosm_assets_bucket_domain_name" {
  value ="${aws_s3_bucket.polycosm-assets.bucket_domain_name}"
}

output "polycosm_assets_bucket_id" {
  value ="${aws_s3_bucket.polycosm-assets.id}"
}

output "polycosm_assets_bucket_region" {
  value ="${var.shared["region"]}"
}
