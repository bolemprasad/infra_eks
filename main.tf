terraform {
  required_version = "~> 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

##### create vpc
resource "aws_vpc" "test_vpc" {
    cidr_block = var.cidr_block
    enable_dns_hostnames = true
    enable_dns_support = true

    tags = var.vpc_tag
  
}

#### create internet gateway
resource "aws_internet_gateway" "test_igw" {
    vpc_id = aws_vpc.test_vpc.id

    tags = var.igw_tag

  
}

########### create subnets two public subnets and private subnets

resource "aws_subnet" "test_pub_sub_1" {
    count = length(var.subnets)
    vpc_id = aws_vpc.test_vpc.id
    cidr_block = var.subnets[count.index]
    availability_zone = var.subnet_azs[count.index]


    tags = var.subnet_tag

  
}

### create 2 private subnets
resource "aws_subnet" "test_private_sub" {
    count = length(var.subnet_private)
    vpc_id = aws_vpc.test_vpc.id
    cidr_block = var.subnet_private[count.index]
    availability_zone = var.private_subnet_azs[count.index]

    tags =  var.private_subnet_tags
}


### cerate a public route table
resource "aws_route_table" "public" {
    vpc_id = aws_vpc.test_vpc.id


    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.test_igw.id
    }
    tags = var.pub_route

}

#### public subnet assosiation
resource "aws_route_table_association" "pub__assosiation" {
    count = length(var.subnets)
    subnet_id = aws_subnet.test_pub_sub_1[count.index].id
    route_table_id = aws_route_table.public.id


}


##### create NAT gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  
}

### NAT gateway in public subnet

resource "aws_nat_gateway" "test_nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id = aws_subnet.test_pub_sub_1[0].id
  depends_on = [ aws_internet_gateway.test_igw ]
  
}

### private route table for private subnets
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.test_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.test_nat_gateway.id
  }
  tags = var.private_route
  
}

### private subnet association
resource "aws_route_table_association" "private_route_association" {
  count = length(var.subnet_private)
  subnet_id = aws_subnet.test_private_sub[count.index].id
  route_table_id = aws_route_table.private_route_table.id
  
}

#### create security groups for bastion server

resource "aws_security_group" "test_security_group" {
  name = "test-security-group"
  vpc_id = aws_vpc.test_vpc.id

  ingress {
    description = "ALLOW SSH connection"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # my internal ip

  }

  egress {
    description = "allow all outbound rules"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  tags = var.sg
  
}

### iam role for ssm
resource "aws_iam_role" "ssm_role" {
  name = "ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ssm_role.name
}


### write for ami
data "aws_ami" "test_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}


####  create a bastion server
resource "aws_instance" "bastion" {
  ami = data.aws_ami.test_ami.id
  instance_type = var.instance_type
  subnet_id = aws_subnet.test_pub_sub_1[0].id
  key_name = var.key_name
  vpc_security_group_ids = [ aws_security_group.test_security_group.id ]
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name

  tags = {
    Name = "bastion-server"
    Env = "Dev"
  }
  
}