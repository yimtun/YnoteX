provider "aws" {
  alias = "virginia"
  region = "us-east-1"
}


resource aws_vpc "test_vpc" {
  provider = aws.virginia
  cidr_block = "10.201.0.0/16"
  tags = {
    Name = "test-vpc"
  }
}

resource "aws_subnet" "test_subnet" {
  provider = aws.virginia
  cidr_block        =  "10.201.11.0/24"
  vpc_id            = aws_vpc.test_vpc.id
  tags = {
    Name = "test_subnet"
  }
  map_public_ip_on_launch = true
}

# https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html

# If a subnet is associated with a route table that has a route to an internet gateway, it's known as a public subnet.
# If a subnet is associated with a route table that does not have a route to an internet gateway, it's known as a private subnet.






resource "aws_route_table" "test_route_table" {
  tags = {
    Name = "test_route_table"
  }
  provider = aws.virginia
  vpc_id = aws_vpc.test_vpc.id
}


resource "aws_route" "internet_access" {
  # This creates the default route to IGW, making the subnet a public subnet.
  provider = aws.virginia
  route_table_id = aws_route_table.test_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.test_igw.id
}

resource "aws_main_route_table_association" "custom_main_route_table" {
  provider = aws.virginia
  vpc_id         = aws_vpc.test_vpc.id
  route_table_id = aws_route_table.test_route_table.id
  lifecycle {
    create_before_destroy = true
  }
}



resource "aws_internet_gateway" "test_igw" {
  tags = {
    Name = "test_igw"
  }
  provider = aws.virginia
  vpc_id = aws_vpc.test_vpc.id
}




resource "aws_instance"  "test1" {
  provider = aws.virginia
  ami           = "ami-0f2425d4cce4e97dd" #rocky9
  #instance_type = "t2.medium" #2C4G
  instance_type = "t2.large" #2C8G
  key_name        = aws_key_pair.my_key_pair.key_name
  subnet_id = aws_subnet.test_subnet.id
  vpc_security_group_ids = [aws_security_group.sshsg.id]
  tags = {
    Name = "test1"
  }
  private_ip = "10.201.11.11"
  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = false
    delete_on_termination = true
  }
}


resource "aws_instance"  "test2" {
  provider = aws.virginia
  ami           = "ami-0f2425d4cce4e97dd" #rocky9
  #instance_type = "t2.medium" #2C4G
  instance_type = "t2.large" #2C8G
  key_name        = aws_key_pair.my_key_pair.key_name
  subnet_id = aws_subnet.test_subnet.id
  vpc_security_group_ids = [aws_security_group.sshsg.id]
  tags = {
    Name = "test2"
  }
  private_ip = "10.201.11.12"
  associate_public_ip_address = true
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = false
    delete_on_termination = true
  }

}





resource "aws_instance"  "test3" {
  provider = aws.virginia
  ami           = "ami-0f2425d4cce4e97dd" #rocky9
  instance_type = "t2.medium" #2C4G
  key_name        = aws_key_pair.my_key_pair.key_name
  subnet_id = aws_subnet.test_subnet.id
  vpc_security_group_ids = [aws_security_group.sshsg.id]
  tags = {
    Name = "test3"
  }
  private_ip = "10.201.11.13"
  associate_public_ip_address = true
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = false
    delete_on_termination = true
  }

}





resource "aws_key_pair" "my_key_pair" {
  provider = aws.virginia
  key_name   = "my-key-pair"  #
  public_key = file("./my_key.pub")  # ssh-keygen -t rsa -b 2048 -f ./my_key -N ""

}


resource "aws_security_group" "sshsg" {
  provider = aws.virginia
  name        = "sshsg"
  description = "sshsg"
  vpc_id      = aws_vpc.test_vpc.id
}



resource "aws_vpc_security_group_ingress_rule" "sshsg" {
  provider = aws.virginia
  security_group_id = aws_security_group.sshsg.id
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = "0.0.0.0/0"


}


# resource "aws_vpc_security_group_ingress_rule" "dlv" {
#   provider = aws.virginia
#   security_group_id = aws_security_group.sshsg.id
#   ip_protocol       = "tcp"
#   from_port         = 2345
#   to_port           = 2346
#   cidr_ipv4         = "x.x.x.x/32"
# }


resource "aws_vpc_security_group_ingress_rule" "icmp" {
  provider = aws.virginia
  security_group_id = aws_security_group.sshsg.id
  ip_protocol       = "icmp"
  from_port         = -1
  to_port           = -1
  cidr_ipv4         = "0.0.0.0/0"
}


resource "aws_vpc_security_group_ingress_rule" "inner" {
  provider = aws.virginia
  security_group_id = aws_security_group.sshsg.id
  ip_protocol       = "-1"
  cidr_ipv4         = "10.201.11.0/24"
}


resource "aws_vpc_security_group_ingress_rule" "https" {
  provider = aws.virginia
  security_group_id = aws_security_group.sshsg.id
  ip_protocol       = "tcp"
  from_port         = 6443
  to_port           = 6443
  cidr_ipv4         = "10.201.11.0/24"
}


resource "aws_vpc_security_group_egress_rule" "sshsg" {
  provider = aws.virginia
  security_group_id = aws_security_group.sshsg.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

output "test1_public_ip" {
  value = aws_instance.test1.public_ip
}


output "test2_public_ip" {
  value = aws_instance.test2.public_ip
}

output "test3_public_ip" {
  value = aws_instance.test3.public_ip
}