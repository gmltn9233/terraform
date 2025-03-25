provider "aws" {
  region = "ap-northeast-2"
}

terraform {
  backend "s3" {
    bucket = "000630-jeff"
    key    = "back/terraform.tfstate"
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
    key    = "alb/back/terraform.tfstate"
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

# Launch template

resource "aws_launch_template" "back_lt" {
  name_prefix            = "Jeff-Back-LT-"
  image_id               = var.ami_id
  instance_type          = var.instance_type
  key_name               = "EC2-weekly"
  vpc_security_group_ids = [aws_security_group.back_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.back_instance_profile.name
  }

  user_data = base64encode(<<-EOF
  #!/bin/bash
  exec > /var/log/user-data.log 2>&1
  set -e

  apt-get update -y
  apt-get install -y curl ruby wget unzip

  # Install AWS CLI v2
  cd /tmp
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  ./aws/install

  # Install Docker
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
  systemctl start docker
  systemctl enable docker

  # Install CodeDeploy Agent
  cd /home/ubuntu
  wget https://aws-codedeploy-ap-northeast-2.s3.amazonaws.com/latest/install
  chmod +x ./install
  ./install auto
  systemctl start codedeploy-agent
  systemctl enable codedeploy-agent

  # 예제 Spring Boot 이미지 다운로드 및 실행
  docker pull nginx
  docker run -d --name my-nginx -p 8080:80 nginx
EOF
  )


  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "Jeff-Back-Server"
      Role = "backend"
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "back_asg" {
  name                = "Jeff-Back-ASG"
  vpc_zone_identifier = [data.terraform_remote_state.vpc.outputs.nat_sub_2_A_id]
  desired_capacity    = 1
  min_size            = 1
  max_size            = 1
  health_check_type   = "EC2"

  launch_template {
    id      = aws_launch_template.back_lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.back_tg.arn]

  tag {
    key   = "Name"
    value = "Jeff-Back-Server"
    # ASG가 생성하는 EC2 인스턴스에도 태그 적용
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "backend"
    propagate_at_launch = true
  }

}

# Target Group 생성 (백엔드 서버 등록)

resource "aws_lb_target_group" "back_tg" {
  name                 = "Jeff-Back-TG"
  port                 = 8080
  protocol             = "HTTP"
  vpc_id               = data.terraform_remote_state.vpc.outputs.vpc_id
  deregistration_delay = 30

  health_check {
    path                = "/"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 20
    matcher             = "200-399"
  }

  tags = {
    Name = "Jeff-Back-TG"
  }
}

# ALB Listner 생성
resource "aws_lb_listener" "back_listner" {
  load_balancer_arn = data.terraform_remote_state.alb.outputs.back_alb_arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.back_tg.arn
  }
}

# EC2가 사용할 IAM Role 생성 (S3와 ECR 접근 허용)
resource "aws_iam_role" "back_ec2_role" {
  name = "Jeff-Back-EC2-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# ECR ReadOnly 권한 부여
resource "aws_iam_role_policy_attachment" "back_ecr_policy_attach" {
  role       = aws_iam_role.back_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# S3 버킷 접근 권한 정책 생성 및 부여
resource "aws_iam_policy" "back_s3_policy" {
  name = "Jeff-Back-EC2-S3-Policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = ["s3:GetObject"],
      Resource = [
        "arn:aws:s3:::jeff-codedeploy-bucket/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "back_s3_policy_attach" {
  role       = aws_iam_role.back_ec2_role.name
  policy_arn = aws_iam_policy.back_s3_policy.arn
}

// ec2 -> ecr 권한
resource "aws_iam_role_policy_attachment" "back_ec2_attach_ecr" {
  role       = aws_iam_role.back_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# IAM Instance Profile 생성
resource "aws_iam_instance_profile" "back_instance_profile" {
  name = "Jeff-Back-InstanceProfile"
  role = aws_iam_role.back_ec2_role.name
}

