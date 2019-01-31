output "postgrest_target_group_id" {
  value = "${aws_alb_target_group.postgrest-alb-group-http.arn}"
}

output "postgrest_security_group_id" {
  value = "${aws_security_group.postgrest.id}"
}

output "postgrest_alb_id" {
  value = "${aws_alb.postgrest-alb.id}"
}
