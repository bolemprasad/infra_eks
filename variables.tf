variable "cidr_block" {
    description = "aws test vpc"
    type = string
    default = "10.0.0.0/16"
  
}


#### varible for vpc tags
variable "vpc_tag" {
    description = "vpc tags"
    type = map(string)
    default = {
        Name = "test_vpc"
        Env = "Dev"
    }
    
}

## tags for IGW
variable "igw_tag" {
    description = "tags for internet gateway"
    type = map(string)
    default = {
        Name = "test_igw"
        Env = "Dev"
    } 
}

#### s3 bucket name
variable "aws_s3_bucket" {
    description = "s3 bucket name"
    type = string
    default = "9100-246-253-123"
  
}


###### write a tags for s3 bucket
variable "s3_bucket_tag" {
    description = "this is s3 bucket tag"
    type = map(string)
    default = {
      "Name" = "9100-246-253"
      Env ="Dev"
    }
  
}

#### variblew for pub-sub-1 
variable "subnets" {
    description = "this is for pub sub 1 "
    type = list(string)
    default = ["10.0.1.0/24", "10.0.2.0/24"]
  
}

#### subnet availability zone
variable "subnet_azs" {
    description = "subnet availibility zone"
    type = list(string)
    default = ["us-east-1a", "us-east-1b"]
}

#### subnet tags
variable "subnet_tag" {
    description = "public subnet tags"
    type = map(string)
    default = {
      "Name" = "pub-sub"
    }
  
}

#### private subnet cidr
variable "subnet_private" {
    description = "private subnet cidr"
    type = list(string)
    default = [ "10.0.4.0/24", "10.0.5.0/24" ]

  
}

### private subnet availibility zone
variable "private_subnet_azs" {
    description = "private subnet availability zone"
    type = list(string)
    default = [ "us-east-1a", "us-east-1b" ]
}

## private subnet tags
variable "private_subnet_tags" {
    description = "private subnet tags"
    type = map(string)
    default = {
      "Name" = "private-sub"
    }
  
}

#### tags for public route table
variable "pub_route" {
    description = "public route table"
    type = map(string)
    default = {
      "Name" = "pub-route-table"
      Env = "Dev"
    }

}
  