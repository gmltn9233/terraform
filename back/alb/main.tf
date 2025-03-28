terraform {
  backend "s3" {
    bucket = "000630-jeff"
    key    = "alb/back/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

data "terraform_remote_state" "front" {
  backend = "s3"
  config = {
    bucket = "000630-jeff"
    key    = "front/terraform.tfstate"
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

data "terraform_remote_state" "openvpn" {
  backend = "s3"
  config = {
    bucket = "000630-jeff"
    key    = "openvpn/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# ALB 보안그룹 생성
resource "aws_security_group" "alb_back_sg" {
  name   = "Jeff-ALB-BACK-SG"
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    description     = "Allow incoming HTTP traffic"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [data.terraform_remote_state.front.outputs.front_sg_id]
  }

  # ALB에서 백엔드 (8080)으로 요청 전달 허용
  ingress {
    description = "Allow ALB to send traffic to backend"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # OpenVPN SG에서 오는 요청 허용
  ingress {
    description     = "Allow VPN access to backend ALB"
    from_port       = 80 # ALB 리스닝 포트
    to_port         = 80
    protocol        = "tcp"
    security_groups = [data.terraform_remote_state.openvpn.outputs.openvpn_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Jeff-ALB-BACK-SG"
  }
}

# ALB 생성
resource "aws_lb" "back_alb" {
  name               = "Jeff-ALB-BACK"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_back_sg.id]
  subnets = [
    data.terraform_remote_state.vpc.outputs.nat_sub_2_A_id,
    data.terraform_remote_state.vpc.outputs.nat_sub_2_C_id
  ]

  tags = {
    Name = "Jeff-ALB-BACK"
  }
}
