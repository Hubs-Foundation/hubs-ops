output "ret_target_group_ids" {
  value = "${aws_alb_target_group.ret-ssl.*.arn}"
}

output "ret_security_group_id" {
  value = "${aws_security_group.ret.id}"
}

output "ret_alb_id" {
  value = "${aws_alb.ret.id}"
}
