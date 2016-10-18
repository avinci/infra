#========================== VPC  =============================

# Define a vpc
resource "aws_vpc" "vpc" {
  cidr_block = "${var.cidr_block}"
  enable_dns_hostnames = true
  tags {
    Name = "${var.vpc}"
  }
}

# Internet gateway for the public subnet
resource "aws_internet_gateway" "ig" {
  vpc_id = "${aws_vpc.vpc.id}"
  tags {
    Name = "ig"
  }
}

#========================== 0.0 Subnet =============================

# Public subnet
resource "aws_subnet" "sn_public" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "${var.cidr_public_ship}"
  availability_zone = "${var.avl-zone}"
  tags {
    Name = "sn_public"
  }
}

# Routing table for public subnet
resource "aws_route_table" "rt_public" {
  vpc_id = "${aws_vpc.vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.ig.id}"
  }
  tags {
    Name = "rt_public"
  }
}

# Associate the routing table to public subnet
resource "aws_route_table_association" "rt_assn_public" {
  subnet_id = "${aws_subnet.sn_public.id}"
  route_table_id = "${aws_route_table.rt_public.id}"
}

#========================== inst subnet ======================
resource "aws_subnet" "sn_ship_install" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "${var.cidr_private_ship_install}"
  availability_zone = "${var.avl-zone}"
  tags {
    Name = "sn_ship_install"
  }
}

# Routing table for private subnet
resource "aws_route_table" "rt_ship_install" {
  vpc_id = "${aws_vpc.vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    instance_id = "${aws_instance.in_nat.id}"
  }
  tags {
    Name = "rt_ship_install"
  }
}

# Associate the routing table to private subnet
resource "aws_route_table_association" "rt_assn_ship_install" {
  subnet_id = "${aws_subnet.sn_ship_install.id}"
  route_table_id = "${aws_route_table.rt_ship_install.id}"
}

#========================== ship-builds subnet ======================
resource "aws_subnet" "sn_ship_builds" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "${var.cidr_private_ship_builds}"
  availability_zone = "${var.avl-zone}"
  tags {
    Name = "sn_ship_builds"
  }
}

# Routing table for private subnet
resource "aws_route_table" "rt_ship_builds" {
  vpc_id = "${aws_vpc.vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    instance_id = "${aws_instance.in_nat.id}"
  }
  tags {
    Name = "rt_ship_builds"
  }
}

# Associate the routing table to private subnet
resource "aws_route_table_association" "rt_assn_ship_builds" {
  subnet_id = "${aws_subnet.sn_ship_builds.id}"
  route_table_id = "${aws_route_table.rt_ship_builds.id}"
}

#========================== NAT =============================

# NAT SG
resource "aws_security_group" "sg_public_nat" {
  name = "sg_public_nat"
  description = "Allow traffic to pass from the private subnet to the internet"

  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "${var.cidr_private_ship_builds}",
      "${var.cidr_private_ship_install}",
    ]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"]
  }
  ingress {
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  egress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [
      "${var.cidr_block}"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Name = "sg_public_nat"
  }
}

# NAT Server
resource "aws_instance" "in_nat" {
  ami = "${var.ami_us_east_1_nat}"
  availability_zone = "${var.avl-zone}"
  instance_type = "${var.in_type_nat}"
  key_name = "${var.aws_key_name}"

  subnet_id = "${aws_subnet.sn_public.id}"
  vpc_security_group_ids = [
    "${aws_security_group.sg_public_nat.id}"]

  associate_public_ip_address = true
  source_dest_check = false

  tags = {
    Name = "in_nat"
  }
}

# Associate EIP, without this private SN wont work
resource "aws_eip" "nat" {
  instance = "${aws_instance.in_nat.id}"
  vpc = true
}

# make this routing table the main one
resource "aws_main_route_table_association" "rt_main_ship_install" {
  vpc_id = "${aws_vpc.vpc.id}"
  route_table_id = "${aws_route_table.rt_ship_install.id}"
}
