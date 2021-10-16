provider "aws" {
  region = var.region
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc-cidr
  enable_dns_hostnames = true
  tags = {
    Project = "Tech Test"
    Owner   = "Anusha"
  }
}

data "aws_availability_zones" "available_zones" {
  state = "available"
}

resource "aws_subnet" "public_subnet" {
  count             = length(data.aws_availability_zones.available_zones.names)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.subnet-cidr-public[count.index]
  availability_zone = data.aws_availability_zones.available_zones.names[count.index]
  tags = {
    Name    = "Subnet${count.index}"
    Project = "Tech Test"
    Owner   = "Anusha"
  }
}


resource "aws_route_table" "public-subnet-route-table" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Project = "Tech Test"
    Owner   = "Anusha"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Project = "Tech Test"
    Owner   = "Anusha"
  }
}

resource "aws_route" "public-subnet-route" {
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
  route_table_id         = aws_route_table.public-subnet-route-table.id
}

resource "aws_route_table_association" "public-subnet-route-table-association" {
  count = length(data.aws_availability_zones.available_zones.names)

  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = aws_route_table.public-subnet-route-table.id
}

#data "aws_subnet" "subnet_values" {
#  for_each = aws_subnet.public_subnet.id
#  id       = each.value
#}

resource "aws_key_pair" "web" {
  public_key = sensitive(file(pathexpand(var.public_key)))
}

resource "aws_launch_configuration" "launch-configuration" {
  name                        = "Nginx-Config-Template"
  image_id                    = "ami-cdbfa4ab"
  instance_type               = "t2.small"
  security_groups             = [aws_security_group.web-instance-security-group.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.web.key_name
  user_data                   = <<EOF
#!/bin/sh
yum install -y nginx
service nginx start
EOF
}


resource "aws_autoscaling_group" "autoscalling_group_config" {
  name                      = "Nginx_autoscale_group"
  max_size                  = 2
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "EC2"
  desired_capacity          = 1
  force_delete              = true
  vpc_zone_identifier       = [for s in aws_subnet.public_subnet : s.id]

  launch_configuration = aws_launch_configuration.launch-configuration.name

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_security_group" "web-instance-security-group" {
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Project = "Tech Test"
    Owner   = "Anusha"
  }
}

#output "web_domain" {
#  value = aws_instance.web-instance.public_dns
#}

