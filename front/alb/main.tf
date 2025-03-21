terraform {
  backend "s3" {
    bucket = "000630-jeff"
    key    = "alb/front/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "000630-jeff"
    key    = "vpc/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# ALB 보안그룹 생성
resource "aws_security_group" "alb_front_sg" {
  name   = "Jeff-ALB-FRONT-SG"
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    description = "Allow incoming HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Jeff-ALB-FRONT-SG"
  }
}

# ALB 생성
resource "aws_lb" "front_alb" {
  name               = "Jeff-ALB-FRONT"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_front_sg.id]
  subnets = [
    data.terraform_remote_state.vpc.outputs.pub_sub_A_id,
    data.terraform_remote_state.vpc.outputs.pub_sub_C_id
  ]

  tags = {
    Name = "Jeff-ALB-FRONT"
  }
}
