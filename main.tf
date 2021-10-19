#specifying provider name along with region where the environment will be setup
provider "aws" {
  region = var.region
}

#creating a new keypair
resource "aws_key_pair" "web" {
  public_key = sensitive(file(pathexpand(var.public_key)))
}

#Creating a VPC
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc-cidr
  enable_dns_hostnames = true
  tags = {
    Project = "Tech Test"
    Owner   = "Anusha"
  }
}

#get all availability zones in the given region
data "aws_availability_zones" "available_zones" {
  state = "available"
}

#Create subnets in all regions except one for resilient application deployment
resource "aws_subnet" "private_subnet" {
  count                   = length(data.aws_availability_zones.available_zones.names) - 1
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.subnet-cidr-public[count.index]
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available_zones.names[count.index]
  tags = {
    Name    = "Subnet${count.index}"
    Project = "Tech Test"
    Owner   = "Anusha"
  }
}

#create subnet in one region for Bastion server
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.subnet-cidr-public[length(data.aws_availability_zones.available_zones.names) - 1]
  availability_zone       = data.aws_availability_zones.available_zones.names[length(data.aws_availability_zones.available_zones.names) - 1]
  map_public_ip_on_launch = true
  tags = {
    Name    = "Public Subnet"
    Project = "Tech Test"
    Owner   = "Anusha"
  }
}

#Create Internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Project = "Tech Test"
    Owner   = "Anusha"
  }
}

#Create a route table
resource "aws_route_table" "public-subnet-route-table" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Project = "Tech Test"
    Owner   = "Anusha"
  }
}

#Create NAT rule
resource "aws_route" "public-subnet-route" {
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
  route_table_id         = aws_route_table.public-subnet-route-table.id
}

#Associate subnets to the route table
resource "aws_route_table_association" "private-subnet-route-table-association" {
  count          = length(data.aws_availability_zones.available_zones.names) - 1
  subnet_id      = element(aws_subnet.private_subnet.*.id, count.index)
  route_table_id = aws_route_table.public-subnet-route-table.id
}

#Associate Bastion subnet to route table
resource "aws_route_table_association" "public-subnet-route-table-associations" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public-subnet-route-table.id
}

#Create security group for Nginx application
resource "aws_security_group" "web-instance-security-group" {
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
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

#Create security group for Bastion server
resource "aws_security_group" "bastion-security-group" {
  vpc_id = aws_vpc.vpc.id

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

#Creating security group for EC2 Bastion Host Access
resource "aws_security_group" "bastion-EC2-SSH-group" {
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion-security-group.id]
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

#Create launch configuration template for autoscaling group
resource "aws_launch_configuration" "launch-configuration" {
  name                        = "Nginx-Config-Template"
  image_id                    = var.imageid
  instance_type               = "t2.small"
  security_groups             = [aws_security_group.web-instance-security-group.id, aws_security_group.bastion-EC2-SSH-group.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.web.key_name
  user_data                   = <<EOF
#!/bin/sh
yum install -y nginx
service nginx start
EOF
}

#Create autoscaling group
resource "aws_autoscaling_group" "autoscalling_group_config" {
  name                      = "Nginx_autoscale_group"
  max_size                  = 2
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "EC2"
  desired_capacity          = 1
  force_delete              = true
  vpc_zone_identifier       = [for s in aws_subnet.private_subnet : s.id]

  launch_configuration = aws_launch_configuration.launch-configuration.name

  lifecycle {
    create_before_destroy = true
  }
}

#Create Bastion launch configuration template for autoscaling group
resource "aws_launch_configuration" "Bastion-launch-configuration" {
  name                        = "Bastion-Config-Template"
  image_id                    = var.imageid
  instance_type               = "t2.small"
  security_groups             = [aws_security_group.bastion-security-group.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.web.key_name
}

#Create Bastion autoscaling group
resource "aws_autoscaling_group" "bastion-autoscalling_group_config" {
  name                      = "Bastion_autoscale_group"
  max_size                  = 1
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "EC2"
  desired_capacity          = 1
  force_delete              = true
  vpc_zone_identifier       = [aws_subnet.public_subnet.id]

  launch_configuration = aws_launch_configuration.Bastion-launch-configuration.name

  lifecycle {
    create_before_destroy = true
  }
}

