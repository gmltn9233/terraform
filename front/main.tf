terraform {
  backend "s3" {
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

data "terraform_remote_state" "alb" {
  backend = "s3"
  config = {
    bucket = "000630-jeff"
    key    = "alb/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

variable "ami_id" {
  description = "프론트 서버용 AMI"
  default     = "ami-0d5bb3742db8fc264"
}

variable "instance_type" {
  description = "프론트 서버 인스턴스 타입"
  default     = "t2.micro"
}

# 프론트 서버 보안 그룹
resource "aws_security_group" "front_sg" {
  name   = "Jeff-Front-SG"
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [data.terraform_remote_state.alb.outputs.alb_sg]
  }

  ingress {
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

  tags = {
    Name = "Jeff-Front-SG"
  }
}

# 프론트 서버 EC2 인스턴스 생성
resource "aws_instance" "front_server" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = "EC2-weekly"
  subnet_id                   = data.terraform_remote_state.vpc.outputs.nat_sub_1_A_id
  vpc_security_group_ids      = [aws_security_group.front_sg.id]
  associate_public_ip_address = false

  user_data = <<-EOF
              #!/bin/bash
              exec > /var/log/user-data.log 2>&1
              set -e

              apt-get update -y
              apt-get install -y curl

              # Docker 공식 설치 스크립트 사용
              curl -fsSL https://get.docker.com -o get-docker.sh
              sh get-docker.sh

              systemctl start docker
              systemctl enable docker

              docker pull nginx
              docker run -d --name my-nginx -p 80:80 nginx
            EOF

  tags = {
    Name = "Jeff-Front-Server"
  }
}

# Target Group 생성 (프론트 서버 등록)

resource "aws_lb_target_group" "front_tg" {
  name     = "Jeff-Front-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.terraform_remote_state.vpc.outputs.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }

  tags = {
    Name = "Jeff-Front-TG"
  }
}

# ALB Listner 생성 (80 포트에서 TG로 포워딩)
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = data.terraform_remote_state.alb.outputs.front_alb_arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.front_tg.arn
  }
}

# ALB와 프론트 서버 인스턴스 연결
resource "aws_lb_target_group_attachment" "front_attachment" {
  target_group_arn = aws_lb_target_group.front_tg.arn
  target_id        = aws_instance.front_server.id
  port             = 80
}

