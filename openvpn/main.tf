provider "aws" {
  region = "ap-northeast-2"
}

terraform {
  backend "s3" {
    bucket = "000630-jeff"
    key    = "openvpn/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "000630-jeff"
    key    = "vpc/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# OpenVPN 보안그룹

resource "aws_security_group" "openvpn_sg" {
  name        = "Jeff-OpenVPN-SG"
  description = "Security group for OpenVPN in public subnet (SSH access)"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    description = "Allow SSH access from trusted IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "OpenVPN Admin UI"
    from_port   = 943
    to_port     = 943
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "OpenVPN HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "OpenVPN UDP Tunnel"
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Jeff-OpenVPN-SG"
  }
}


resource "aws_instance" "openvpn" {
  ami             = "ami-09a093fa2e3bfca5a"
  instance_type   = "t2.medium"
  key_name        = "EC2-weekly"
  subnet_id       = data.terraform_remote_state.vpc.outputs.pub_sub_A_id
  security_groups = [aws_security_group.openvpn_sg.id]

  tags = {
    Name = "OpenVPN-Jeff"
  }
}
