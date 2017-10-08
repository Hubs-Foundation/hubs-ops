output "hab_security_group_id" {
  value = "${aws_security_group.hab.id}"
}

output "hab_ring_security_group_id" {
  value = "${aws_security_group.hab-ring.id}"
}
