# Create the main VPC for the AWS Landing Zone

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "landing-zone-vpc"
  }
}
# Create a public subnet for internet-facing resources

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}
# Create a private subnet for internal resources

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = "ap-south-1a"

  tags = {
    Name = "private-subnet"
  }
}
# Create and attach an Internet Gateway to the VPC

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "landing-zone-igw"
  }
}
# Create a public route table and route internet traffic through the Internet Gateway
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}
# Associate the public subnet with the public route table

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}


# Create an Elastic IP for the NAT Gateway

resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "nat-gateway-eip"
  }
}

# Create a NAT Gateway in the Public Subnet

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "landing-zone-nat-gateway"
  }

  depends_on = [
    aws_internet_gateway.igw
  ]
}


# Create a Private Route Table

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private-route-table"
  }
}


# Associate Private Subnet with Private Route Table

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

# Security Group for Public EC2 (Bastion Host)

resource "aws_security_group" "public_sg" {

  name        = "public-security-group"
  description = "Allow SSH, HTTP and HTTPS"
  vpc_id      = aws_vpc.main.id

  ingress {

    description = "SSH"

    from_port = 22

    to_port = 22

    protocol = "tcp"

    cidr_blocks = ["0.0.0.0/0"]

  }

  ingress {

    description = "HTTP"

    from_port = 80

    to_port = 80

    protocol = "tcp"

    cidr_blocks = ["0.0.0.0/0"]

  }

  ingress {

    description = "HTTPS"

    from_port = 443

    to_port = 443

    protocol = "tcp"

    cidr_blocks = ["0.0.0.0/0"]

  }

  egress {

    from_port = 0

    to_port = 0

    protocol = "-1"

    cidr_blocks = ["0.0.0.0/0"]

  }

  tags = {

    Name = "Public-SG"

  }

}

# Security Group for Private EC2


resource "aws_security_group" "private_sg" {

  name        = "private-security-group"
  description = "Allow SSH only from Public Security Group"
  vpc_id      = aws_vpc.main.id

  ingress {

    description = "SSH from Public Security Group"

    from_port = 22

    to_port = 22

    protocol = "tcp"

    security_groups = [aws_security_group.public_sg.id]

  }

  egress {

    from_port = 0

    to_port = 0

    protocol = "-1"

    cidr_blocks = ["0.0.0.0/0"]

  }

  tags = {

    Name = "Private-SG"

  }

}

# Create AWS Key Pair


resource "aws_key_pair" "terraform_key" {
  key_name   = "terraform-key"
  public_key = file("${path.module}/terraform-key.pub")

  tags = {
    Name = "terraform-key"
  }
}

# Get Latest Amazon Linux 2023 AMI

data "aws_ami" "amazon_linux" {

  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

}

# Bastion Host EC2

resource "aws_instance" "bastion" {

  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  subnet_id = aws_subnet.public_subnet.id

  vpc_security_group_ids = [aws_security_group.public_sg.id]

  key_name = aws_key_pair.terraform_key.key_name

  associate_public_ip_address = true

  tags = {

    Name = "Bastion-Host"

  }

}

# Private Application Server

resource "aws_instance" "private_server" {

  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  subnet_id = aws_subnet.private_subnet.id

  vpc_security_group_ids = [aws_security_group.private_sg.id]

  key_name = aws_key_pair.terraform_key.key_name

  associate_public_ip_address = false

  tags = {
    Name = "Application-Server"
  }
}

# IAM Role for EC2

resource "aws_iam_role" "ec2_role" {

  name = "ec2-role"

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


# Attach Amazon S3 Read Only Policy to EC2 Role

resource "aws_iam_role_policy_attachment" "s3_readonly" {

  role = aws_iam_role.ec2_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"

}

# Create Instance Profile

resource "aws_iam_instance_profile" "ec2_profile" {

  name = "ec2-profile"

  role = aws_iam_role.ec2_role.name

}

# S3 Bucket for Terraform State

resource "aws_s3_bucket" "terraform_state" {

  bucket = "ajeet-terraform-state-2026"

  tags = {
    Name = "Terraform-State"
  }

}