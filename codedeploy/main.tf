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

  trigger_configuration {
    trigger_events     = ["DeploymentSuccess", "DeploymentFailure"]
    trigger_name       = "frontend-deploy-events"
    trigger_target_arn = aws_sns_topic.codedeploy_notifications.arn
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

  trigger_configuration {
    trigger_events     = ["DeploymentSuccess", "DeploymentFailure"]
    trigger_name       = "backend-deploy-events"
    trigger_target_arn = aws_sns_topic.codedeploy_notifications.arn
  }

  autoscaling_groups = [data.terraform_remote_state.back.outputs.back_asg_name]
}


# 배포 알림

# SNS Topic 생성
resource "aws_sns_topic" "codedeploy_notifications" {
  name = "codedeploy-notification"
}

# Lambda 실행 역할 생성 (SNS 권한 포함)

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda-codedeploy-slack-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logging" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "sns_policy" {
  name = "LambdaSNSTriggerPolicy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "sns:Publish",
        "sns:Subscribe"
      ],
      Resource = "*"
    }]
  })
}

# Lambda 함수 생성 및 SNS 트리거 연결
resource "aws_lambda_function" "codedeploy_notifier" {
  function_name    = "codedeploy-slack-notifier"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  filename         = "lambda.zip"
  source_code_hash = filebase64sha256("lambda.zip")

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }
}

resource "aws_lambda_permission" "sns_invoke_lambda" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.codedeploy_notifier.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.codedeploy_notifications.arn
}

resource "aws_sns_topic_subscription" "sns_to_lambda" {
  topic_arn = aws_sns_topic.codedeploy_notifications.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.codedeploy_notifier.arn
}
