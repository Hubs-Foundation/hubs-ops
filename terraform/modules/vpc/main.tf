# Modified from https://charity.wtf/2016/04/14/scrapbag-of-useful-terraform-tips/

variable "shared" { type = "map" }
terraform { backend "s3" {} }
provider "aws" { region = "${var.shared["region"]}", version = "~> 0.1" }
data "aws_availability_zones" "all" {}

resource "aws_vpc" "mod" {
  cidr_block = "${var.cidr}"
  tags { 
    Name = "${var.shared["env"]}-mr-vpc"
  }
}

resource "aws_internet_gateway" "mod" {
  vpc_id = "${aws_vpc.mod.id}"
  tags { 
    Name = "${var.shared["env"]}-igw"
  }
}

# for each in the list of availability zones, create the public subnet 
# and private subnet for that list index,
# then create an EIP and attach a nat_gateway for each one.  and an aws route
# table should be created for each private subnet, and add the correct nat_gw

resource "aws_subnet" "private" {
  vpc_id = "${aws_vpc.mod.id}"
  cidr_block = "${element(split(",", var.private_ranges), count.index)}"
  availability_zone = "${element(split(",", var.shared["azs"]), count.index)}"
  count = "${length(compact(split(",", var.private_ranges)))}"
  tags { 
    Name = "${var.shared["env"]}-private-${count.index}"
  }
}

resource "aws_subnet" "public" {
  vpc_id = "${aws_vpc.mod.id}"
  cidr_block = "${element(split(",", var.public_ranges), count.index)}"
  availability_zone = "${element(split(",", var.shared["azs"]), count.index)}"
  count = "${length(compact(split(",", var.public_ranges)))}"
  tags { 
    Name = "${var.shared["env"]}-public-${count.index}"
  }
  map_public_ip_on_launch = true
}

# refactor to take all the route {} sections out of routing tables, 
# and turn them into associated aws_route resources
# so we can add vpc peering routes from specific environments.
resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.mod.id}"
  tags { 
    Name = "${var.shared["env"]}-public-subnet_route_table"
  }
}

# add a public gateway to each public route table
resource "aws_route" "public_gateway_route" {
  route_table_id = "${aws_route_table.public.id}"
  depends_on = ["aws_route_table.public"]
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = "${aws_internet_gateway.mod.id}"
}

resource "aws_eip" "nat_eip" {
  count    = "${length(split(",", var.public_ranges))}"
  depends_on = ["aws_internet_gateway.mod"]
  vpc = true
}

resource "aws_nat_gateway" "nat_gw" {
  count = "${length(split(",", var.public_ranges))}"
  allocation_id = "${element(aws_eip.nat_eip.*.id, count.index)}"
  subnet_id = "${element(aws_subnet.public.*.id, count.index)}"
  depends_on = ["aws_internet_gateway.mod"]
}

# for each of the private ranges, create a "private" route table.
resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.mod.id}"
  count = "${length(compact(split(",", var.private_ranges)))}"
  tags {
    Name = "${var.shared["env"]}-private-subnet_route_table_${count.index}"
  }
}

# add a nat gateway to each private subnet's route table
resource "aws_route" "private_nat_gateway_route" {
  count = "${length(compact(split(",", var.private_ranges)))}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  depends_on = ["aws_route_table.private"]
  nat_gateway_id = "${element(aws_nat_gateway.nat_gw.*.id, count.index)}"
}

# gonna need a custom route association for each range too
resource "aws_route_table_association" "private" {
  count = "${length(compact(split(",", var.private_ranges)))}"
  subnet_id = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
}

resource "aws_route_table_association" "public" {
  count = "${length(compact(split(",", var.public_ranges)))}"
  subnet_id = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}
