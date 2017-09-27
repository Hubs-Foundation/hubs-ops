output "vpc_id" {
  value = "${aws_vpc.mod.id}"
}

output "vpc_cidr_block" {
  value = "${aws_vpc.mod.cidr_block}"
}

output "public_subnet_ids" {
  value = "${aws_subnet.public.*.id}"
}

output "private_subnet_ids" {
  value = "${aws_subnet.private.*.id}"
}
