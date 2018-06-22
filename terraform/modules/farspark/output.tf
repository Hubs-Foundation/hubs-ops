output "farspark_target_group_id" {
  value = "${aws_alb_target_group.farspark-alb-group-http.arn}"
}

output "farspark_security_group_id" {
  value = "${aws_security_group.farspark.id}"
}

output "farspark_alb_id" {
  value = "${aws_alb.farspark-alb.id}"
}
