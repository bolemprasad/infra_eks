#WS VPC + Bastion + Private Subnets (Terraform)
📌 Overview

This repository provisions a secure AWS network architecture using Terraform, consisting of:

Custom VPC

2 Public Subnets

2 Private Subnets

Internet Gateway

NAT Gateway

Route Tables (Public & Private)

Bastion EC2 instance

AWS Systems Manager (SSM) access

The design follows AWS best practices, where:

Public access is limited

Private workloads (EKS in future) run in private subnets

Bastion access is done securely using SSM (no direct SSH required)

#Architecture (Update in feature)

Internet
   |
[Internet Gateway]
   |
[Public Subnets]
   |—— Bastion EC2 (SSM Access)
   |
[NAT Gateway]
   |
[Private Subnets]
   |
(Future: EKS Cluster)
