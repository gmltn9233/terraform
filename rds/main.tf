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

data "terraform_remote_state" "back" {
  backend = "s3"
  config = {
    bucket = "000630-jeff"
    key    = "back/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# 서브넷 그룹
resource "aws_db_subnet_group" "rds_subnet_group" {
  name = "jeff-rds-subnet-group"
  subnet_ids = [
    data.terraform_remote_state.vpc.outputs.prv_sub_A_id,
    data.terraform_remote_state.vpc.outputs.prv_sub_C_id
  ]

  tags = {
    Name = "jeff-rds-subnet-group"
  }
}

# RDS 보안그룹
resource "aws_security_group" "rds_sg" {

  name   = "jeff-rds-sg"
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id

  # 백엔드 서버 SG
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [data.terraform_remote_state.back.outputs.back_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jeff-rds-sg"
  }
}

# RDS

resource "aws_db_instance" "rds" {
  identifier             = "jeff-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  username               = var.db_username
  password               = var.db_password
  db_name                = "jeff-db"
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  # 고가용성
  multi_az = true

  tags = {
    Name = "jeff-db"
  }
}

