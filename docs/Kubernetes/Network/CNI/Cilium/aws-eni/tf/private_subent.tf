provider "aws" {
  alias  = "Ohio"
  region = "us-east-2"
}

# ======================
# VPC
# ======================
resource "aws_vpc" "Ohio_vpc" {
  provider   = aws.Ohio
  cidr_block = "10.201.0.0/16"
  tags = { Name = "Ohio_vpc" }
}

# ======================
# public subnet
# ======================
resource "aws_subnet" "public_subnet" {
  provider                  = aws.Ohio
  vpc_id                    = aws_vpc.Ohio_vpc.id
  cidr_block                = "10.201.10.0/24"
  map_public_ip_on_launch   = true
  tags = { Name = "public_subnet" }
}

# ======================
# private subnet
# ======================
resource "aws_subnet" "private_subnet" {
  provider                  = aws.Ohio
  vpc_id                    = aws_vpc.Ohio_vpc.id
  cidr_block                = "10.201.11.0/24"
  map_public_ip_on_launch   = false
  tags = { Name = "private_subnet" }
}

# ======================
# public subent rt
# ======================
resource "aws_internet_gateway" "igw" {
  provider = aws.Ohio
  vpc_id   = aws_vpc.Ohio_vpc.id
  tags = { Name = "igw" }
}

resource "aws_route_table" "public_rt" {
  provider = aws.Ohio
  vpc_id   = aws_vpc.Ohio_vpc.id
  tags     = { Name = "public_rt" }
}

resource "aws_route" "default_route" {
  provider                 = aws.Ohio
  route_table_id           = aws_route_table.public_rt.id
  destination_cidr_block   = "0.0.0.0/0"
  gateway_id               = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  provider        = aws.Ohio
  subnet_id       = aws_subnet.public_subnet.id
  route_table_id  = aws_route_table.public_rt.id
}

# ======================
# nat gw
# ======================
resource "aws_eip" "nat_eip" {
  provider = aws.Ohio
  domain   = "vpc"
  tags     = { Name = "nat_eip" }
}

resource "aws_nat_gateway" "nat_gw" {
  provider      = aws.Ohio
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id
  tags          = { Name = "nat_gw" }
}

# private subent rt
resource "aws_route_table" "private_rt" {
  provider = aws.Ohio
  vpc_id   = aws_vpc.Ohio_vpc.id
  tags     = { Name = "private_rt" }
}

resource "aws_route" "private_default_route" {
  provider                 = aws.Ohio
  route_table_id           = aws_route_table.private_rt.id
  destination_cidr_block   = "0.0.0.0/0"
  nat_gateway_id           = aws_nat_gateway.nat_gw.id
}

resource "aws_route_table_association" "private_assoc" {
  provider        = aws.Ohio
  subnet_id       = aws_subnet.private_subnet.id
  route_table_id  = aws_route_table.private_rt.id
}

# ======================
# Key Pair
# ======================
resource "aws_key_pair" "Ohio" {
  provider   = aws.Ohio
  key_name   = "my-key-pair"
  public_key = file("./my_key.pub")
}

# ======================
# bastion_sg
# ======================
# Bastion bastion_sg
resource "aws_security_group" "bastion_sg" {
  provider    = aws.Ohio
  vpc_id      = aws_vpc.Ohio_vpc.id
  name        = "bastion_sg"

  ingress {
    description = "SSH from anywhere"
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
}

# private_sg
resource "aws_security_group" "private_sg" {
  provider    = aws.Ohio
  vpc_id      = aws_vpc.Ohio_vpc.id
  name        = "private_sg"

  ingress {
    description = "SSH from Bastion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.public_subnet.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ======================
# public instance (Bastion)
# ======================
resource "aws_instance" "bastion" {
  provider                  = aws.Ohio
  ami                       = "ami-0d1b5a8c13042c939" #ubuntu
  instance_type             = "t2.medium"
  key_name                  = aws_key_pair.Ohio.key_name
  subnet_id                 = aws_subnet.public_subnet.id
  vpc_security_group_ids    = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true
  tags = { Name = "bastion" }
}

# ======================
# private instance
# ======================
resource "aws_instance" "private_instance" {
  provider                  = aws.Ohio
  ami                       = "ami-0d1b5a8c13042c939" #ubuntu
  instance_type             = "t2.medium"
  key_name                  = aws_key_pair.Ohio.key_name
  subnet_id                 = aws_subnet.private_subnet.id
  vpc_security_group_ids    = [aws_security_group.private_sg.id]
  associate_public_ip_address = false
  tags = { Name = "private_instance" }
}
output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}
# ssh -i ./my_key  ubuntu@bastion_public_ip