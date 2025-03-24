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

data "terraform_remote_state" "back" {
  backend = "s3"
  config = {
    bucket = "000630-jeff"
    key    = "back/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# S3 버킷 생성

resource "aws_s3_bucket" "codedeploy_bucket" {
  bucket = "jeff-codedeploy-bucket"

  tags = {
    Name = "codedeploy-bucket"
  }
}


# codedeploy role 부여

resource "aws_iam_role" "codedeploy_role" {
  name = "CodeDeployServiceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "codedeploy.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy_role_attach" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

# codedeploy 애플리케이션 생성

resource "aws_codedeploy_app" "app" {
  name             = "Jeff-app"
  compute_platform = "Server"
}

# 프론트/백엔드 배포 그룹 생성

# 프론트

resource "aws_codedeploy_deployment_group" "frontend" {
  app_name              = aws_codedeploy_app.app.name
  deployment_group_name = "frontend-group"
  service_role_arn      = aws_iam_role.codedeploy_role.arn

  deployment_style {
    // 현재 실행중인 인스턴스에 덮어쓰기
    deployment_type   = "IN_PLACE"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  ec2_tag_set {
    ec2_tag_filter {
      key   = "Role"
      type  = "KEY_AND_VALUE"
      value = "frontend"
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  load_balancer_info {
    target_group_info {
      name = data.terraform_remote_state.front.outputs.front_tg_name
    }
  }

  autoscaling_groups = [data.terraform_remote_state.front.outputs.front_asg_name]
}


# 백엔드

resource "aws_codedeploy_deployment_group" "backend" {
  app_name              = aws_codedeploy_app.app.name
  deployment_group_name = "backend-group"
  service_role_arn      = aws_iam_role.codedeploy_role.arn

  deployment_style {
    // 현재 실행중인 인스턴스에 덮어쓰기
    deployment_type   = "IN_PLACE"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  ec2_tag_set {
    ec2_tag_filter {
      key   = "Role"
      type  = "KEY_AND_VALUE"
      value = "backend"
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  load_balancer_info {
    target_group_info {
      name = data.terraform_remote_state.back.outputs.back_tg_name
    }
  }

  autoscaling_groups = [data.terraform_remote_state.back.outputs.back_asg_name]
}
