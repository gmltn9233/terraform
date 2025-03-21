provider "aws" {
  region = "ap-northeast-2"
}


# RDS 보안그룹 생성
resource "aws_security_group" "rds_sg" {
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port = 3306
    to_port   = 3306
    protocol  = "tcp"

  }
}


