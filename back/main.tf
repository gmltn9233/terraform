provider "aws" {
  region = "ap=northeast-2"
}

module "vpc" {
  source = "../vpc"
}

# 보안그룹
resource "aws_security_group" "backend_sg" {
  vpc_id = module.vpc.vpc_id
  
  # 같은 VPC 내부에서만 SSH(22) 접근 허용  
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [module.vpc.vpc.main_cidr]
  }

  # 스프링 서버 기본 포트 8080 허용
  ingress{
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = 
  }

  
}
