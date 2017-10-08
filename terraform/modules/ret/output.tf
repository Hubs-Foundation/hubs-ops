output "ret_target_group_id" {
  value = "${aws_alb_target_group.ret-alb-group-http.arn}"
}

output "ret_security_group_id" {
  value = "${aws_security_group.ret.id}"
}

output "ret_alb_id" {
  value = "${aws_alb.ret-alb.id}"
}
