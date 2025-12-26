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
resource "aws_route_table_association" "pub_sub_assosiation" {
    count = length(var.pub

}
