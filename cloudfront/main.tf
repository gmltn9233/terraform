provider "aws" {
  region = "ap-northeast-2"
}

data "terraform_remote_state" "alb" {
  backend = "s3"
  config = {
    bucket = "000630-jeff"
    key    = "alb/front/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

resource "aws_cloudfront_distribution" "frontend_cdn" {
  origin {
    domain_name = data.terraform_remote_state.alb.outputs.front_alb_dns_name
    origin_id   = "jeff-front-alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "/"

  # 커스텀 도메인 연결
  aliases = [var.custom_dns]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "jeff-front-alb"

    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
  }

  viewer_certificate {
    acm_certificate_arn      = var.cert_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = "jeff-frontend-cdn"
  }
}

