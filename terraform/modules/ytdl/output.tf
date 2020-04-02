output "ytdl_target_group_id" {
  value = "${aws_alb_target_group.ytdl-alb-group-http.arn}"
}

output "ytdl_security_group_id" {
  value = "${aws_security_group.ytdl.id}"
}

output "ytdl_alb_id" {
  value = "${aws_alb.ytdl-alb.id}"
}
