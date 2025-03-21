provider "aws" {
  region = "ap=northeast-2"
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

variable "ami_id" {
  description = "백엔드 서버용 AMI"
  default     = "ami-0d5bb3742db8fc264"
}

variable "instance_type" {
  description = "백엔드 서버 인스턴스 타입"
  default     = "t2.micro"
}

# 보안그룹
resource "aws_security_group" "back_sg" {
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id

  # 같은 VPC 내부에서만 SSH(22) 접근 허용  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 스프링 서버 기본 포트 8080 허용
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [data.terraform_remote_state.alb.outputs.alb_back_sg]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Jeff-Backend-SG"
  }
}


# 백엔드 서버 EC2 인스턴스 생성
resource "aws_instance" "back_server" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = "EC2-weekly"
  subnet_id                   = data.terraform_remote_state.vpc.outputs.nat_sub_2_A_id
  vpc_security_group_ids      = [aws_security_group.back_sg.id]
  associate_public_ip_address = false

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install docker -y
              service docker start
              usermod -a -G docker ec2-user

              # 예시 Spring Boot Docker 이미지 실행 (hello-world app)
              docker run -d -p 8080:8080 jeonguk/spring-boot-hello-world

              # 부팅 시 자동 실행 설정
              systemctl enable docker
            EOF

  tags = {
    Name = "Jeff-Backend-Server"
  }
}


# Target Group 생성 (백엔드 서버 등록)

resource "aws_lb_target_group" "back_tg" {
  name     = "Jeff-Back-TG"
  port     = 8080
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
    Name = "Jeff-Back-TG"
  }
}


# ALB와 백엔드 서버 인스턴스 연결
resource "aws_lb_target_group_attachment" "back_attachment" {
  target_group_arn = aws_lb_target_group.back_tg.arn
  target_id        = aws_instance.back_server.id
  port             = 8080
}

