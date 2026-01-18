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


    tags = merge(
    var.subnet_tag,
    {
      "kubernetes.io/role/elb" = "1"
      "kubernetes.io/cluster/test-eks-cluster" = "shared"
    }
  )

  
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
    tags = merge(
    var.private_subnet_tags,
    {
      "kubernetes.io/role/internal-elb" = "1"
      "kubernetes.io/cluster/test-eks-cluster" = "shared"
    }
  )

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

/*
  ingress {
  from_port   = 2222
  to_port     = 2222
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
*/


  egress {
    description = "allow all outbound rules"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  tags = var.sg
  
}
###########
resource "aws_security_group_rule" "eks_api_from_bastion" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"

  security_group_id         = aws_eks_cluster.test_eks_cluster.vpc_config[0].cluster_security_group_id
  source_security_group_id  = aws_security_group.test_security_group.id
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
  #iam_instance_profile = aws_iam_instance_profile.ssm_profile.name
  iam_instance_profile = aws_iam_instance_profile.bastion_eks_profile.name

  user_data = <<-EOF
  #!/bin/bash
  set -e

  # Install dependencies
  sudo yum update -y
  sudo yum install -y unzip curl

  # Install AWS CLI v2
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  sudo ./aws/install --update

  # Install kubectl
  curl -LO "https://dl.k8s.io/release/v1.29.0/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/

  EOF


  tags = {
    Name = "bastion-server"
    Env = "Dev"
  }
  
}

##############
data "aws_caller_identity" "current" {}


### creating new role for bastion this is commenting the below role
/*
resource "aws_iam_role" "bastion_eks_role" {
  name = "bastion-eks-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = { Service = "ec2.amazonaws.com" },
        Action = "sts:AssumeRole"
      },
      {
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/bastion-eks-role"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}
*/

#### this is new role for bastion eks 
resource "aws_iam_role" "bastion_eks_role" {
  name = "bastion-eks-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = { Service = "ec2.amazonaws.com" },
        Action = "sts:AssumeRole"
      }
    ]
  })
}



/*
resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion_eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
*/

resource "aws_iam_role_policy_attachment" "bastion_eks" {
  role       = aws_iam_role.bastion_eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_instance_profile" "bastion_eks_profile" {
  name = "bastion-eks-profile"
  role = aws_iam_role.bastion_eks_role.name
}

##################################

resource "aws_iam_role_policy_attachment" "bastion_eks_access_k8s" {
  role       = aws_iam_role.bastion_eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

#########################
resource "aws_iam_policy" "bastion_k8s_api" {
  name = "bastion-k8s-api-access"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:AccessKubernetesApi"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "sts:AssumeRole"
        ],
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/bastion-eks-role"
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "bastion_k8s_api_attach" {
  role       = aws_iam_role.bastion_eks_role.name
  policy_arn = aws_iam_policy.bastion_k8s_api.arn
}



#### create IAM role for eks cluster

resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

### policy attachment
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}


#### create EKS cluster
resource "aws_eks_cluster" "test_eks_cluster" {
  name = "test-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids              = aws_subnet.test_private_sub[*].id
    endpoint_private_access = true
    endpoint_public_access = false
  }
  
}


#### create iam role for eks nodes
resource "aws_iam_role" "test_eks_node_role" {
  name = "test-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

##########################
resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion_eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_policy" "bastion_eks_read_policy" {
  name = "bastion-eks-read-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "bastion_eks_read_attach" {
  role       = aws_iam_role.bastion_eks_role.name
  policy_arn = aws_iam_policy.bastion_eks_read_policy.arn
}






### policy attachment for nodes
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role = aws_iam_role.test_eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role = aws_iam_role.test_eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  
}

resource "aws_iam_role_policy_attachment" "eks_ecr_policy" {
  role = aws_iam_role.test_eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  
}

/*
resource "aws_iam_role_policy_attachment" "bastion_eks_access" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
*/

/*
resource "aws_iam_role_policy_attachment" "bastion_eks_readonly" {
  role       = aws_iam_role.bastion_eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSReadOnlyAccess"
}
*/




##########create eks node group
resource "aws_eks_node_group" "test_node_group" {
  cluster_name = aws_eks_cluster.test_eks_cluster.name
  node_group_name = "test-node-group"
  node_role_arn = aws_iam_role.test_eks_node_role.arn
  subnet_ids = aws_subnet.test_private_sub[*].id

  scaling_config {
    desired_size = 2
    min_size = 1
    max_size = 4
  }
  instance_types = ["t3.micro"]
  capacity_type = "ON_DEMAND"
  depends_on = [ aws_iam_role_policy_attachment.eks_worker_node_policy, aws_iam_role_policy_attachment.eks_cni_policy, aws_iam_role_policy_attachment.eks_ecr_policy ]
}
