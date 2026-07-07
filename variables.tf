# AWS Region
variable "aws_region" {
  description = "AWS Region"
  type        = string
}

# VPC CIDR
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
 
}

# Public Subnet CIDR
variable "public_subnet_cidr" {
  description = "CIDR block for Public Subnet"
  type        = string
  
}

# Private Subnet CIDR
variable "private_subnet_cidr" {
  description = "CIDR block for Private Subnet"
  type        = string
  
}

# EC2 Instance Type
variable "instance_type" {
  description = "EC2 Instance Type"
  type        = string
  
}