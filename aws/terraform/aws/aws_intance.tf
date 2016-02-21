variable "availability_zone" {}
variable "datacenter" {default = "aws"}
variable "addtional_volume_size" {default = "100"} # size is in gigabytes
variable "network_ipv4" {default = "10.0.0.0/16"}
variable "network_subnet_ip4" {default = "10.0.0.0/16"}
variable "long_name" {default = "spark_demo"}
variable "short_name" {default = "spark"}
variable "source_ami" { }
variable "ssh_key" {default = "~/.ssh/id_rsa.pub"}
variable "ssh_username"  {default = "ubuntu"}
variable "master_count" {default = "3"}
variable "master_type" {default = "m1.small"}
variable "worker_count" {default = "1"}
variable "worker_type" {default = "m1.small"}
variable "master_volume_size" {default = "20"} # size is in gigabytes
variable "worker_volume_size" {default = "20"} # size is in gigabytes
variable "master_iam_profile" { default = "" }
variable "worker_iam_profile" { default = "" }

resource "aws_vpc" "main" {
  cidr_block = "${var.network_ipv4}"
  enable_dns_hostnames = true
  tags {
    Name = "${var.long_name}"
  }
}

resource "aws_subnet" "main" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "${var.network_subnet_ip4}"
  availability_zone = "${var.availability_zone}"
  tags {
    Name = "${var.long_name}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = "${aws_vpc.main.id}"
  tags {
    Name = "${var.long_name}"
  }
}

resource "aws_route_table" "main" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.main.id}"
  }

  tags {
    Name = "${var.long_name}"
  }
}

resource "aws_main_route_table_association" "main" {
  vpc_id = "${aws_vpc.main.id}"
  route_table_id = "${aws_route_table.main.id}"
}

resource "aws_ebs_volume" "mi-master-addtional" {
  availability_zone = "${var.availability_zone}"
  count = "${var.master_count}"
  size = "${var.addtional_volume_size}"
  type = "gp2"

  tags {
    Name = "${var.short_name}-master-addtional-${format("%02d", count.index+1)}"
  }
}

resource "aws_instance" "mi-master-nodes" {
  ami = "${var.source_ami}"
  availability_zone = "${var.availability_zone}"
  instance_type = "${var.master_type}"
  count = "${var.master_count}"

  vpc_security_group_ids = ["${aws_security_group.master.id}",
    "${aws_security_group.inner.id}",
    "${aws_vpc.main.default_security_group_id}"]


  key_name = "${aws_key_pair.deployer.key_name}"

  associate_public_ip_address=true

  iam_instance_profile = "${var.master_iam_profile}"

  subnet_id = "${aws_subnet.main.id}"

  root_block_device {
    delete_on_termination = true
    volume_size = "${var.master_volume_size}"
  }

  tags {
    Name = "${var.short_name}-master-${format("%03d", count.index+1)}"
    sshUser = "${var.ssh_username}"
    role = "master"
    dc = "${var.datacenter}"
  }
}

resource "aws_volume_attachment" "mi-master-nodes-addtional-attachment" {
  count = "${var.master_count}"
  device_name = "xvdh"
  instance_id = "${element(aws_instance.mi-master-nodes.*.id, count.index)}"
  volume_id = "${element(aws_ebs_volume.mi-master-addtional.*.id, count.index)}"
  force_detach = true
}

resource "aws_instance" "mi-worker-nodes" {
  ami = "${var.source_ami}"
  availability_zone = "${var.availability_zone}"
  instance_type = "${var.worker_type}"
  count = "${var.worker_count}"

  vpc_security_group_ids = ["${aws_security_group.worker.id}",
    "${aws_security_group.inner.id}",
    "${aws_vpc.main.default_security_group_id}"]


  key_name = "${aws_key_pair.deployer.key_name}"

  associate_public_ip_address=true

  iam_instance_profile = "${var.worker_iam_profile}"

  subnet_id = "${aws_subnet.main.id}"

  root_block_device {
    delete_on_termination = true
    volume_size = "${var.worker_volume_size}"
  }

  ebs_block_device {
    device_name = "xvdh"
    volume_type = "gp2"
    volume_size = "${var.addtional_volume_size}"
    delete_on_termination = true
  }

  tags {
    Name = "${var.short_name}-worker-${format("%03d", count.index+1)}"
    sshUser = "${var.ssh_username}"
    role = "worker"
    dc = "${var.datacenter}"
  }
}

resource "aws_security_group" "master" {
  name = "${var.short_name}-master"
  description = "Allow inbound traffic for worker nodes"
  vpc_id="${aws_vpc.main.id}"

  ingress { # SSH
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress { # ICMP
    from_port=-1
    to_port=-1
    protocol = "icmp"
    cidr_blocks=["0.0.0.0/0"]
  }
}

resource "aws_security_group" "worker" {
  name = "${var.short_name}-worker"
  description = "Allow inbound traffic for worker nodes"
  vpc_id="${aws_vpc.main.id}"

  ingress { # SSH
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress { # ICMP
    from_port=-1
    to_port=-1
    protocol = "icmp"
    cidr_blocks=["0.0.0.0/0"]
  }
}

resource "aws_security_group" "inner" {
  name = "${var.short_name}-inner"
  description = "Allow inbound traffic for all ports"
  vpc_id="${aws_vpc.main.id}"

  ingress { # Control
    from_port=0
    to_port=65535
    protocol = "tcp"
    self = true
  }

  ingress { # Control
    from_port=0
    to_port=65535
    protocol = "udp"
    self = true
  }
}

resource "aws_key_pair" "deployer" {
  key_name = "key-${var.short_name}"
  public_key = "${file(var.ssh_key)}"
}

output "master_private_ips" {
  value = "${join(\",\", aws_instance.mi-master-nodes.*.private_ip)}"
}

output "worker_private_ips" {
  value = "${join(\",\", aws_instance.mi-worker-nodes.*.private_ip)}"
}

output "master_public_ips" {
  value = "${join(\",\", aws_instance.mi-master-nodes.*.public_ip)}"
}

output "worker_public_ips" {
  value = "${join(\",\", aws_instance.mi-worker-nodes.*.public_ip)}"
}
