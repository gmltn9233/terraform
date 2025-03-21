output "alb_back_sg" {
  description = "alb_back_sg"
  value       = aws_security_group.alb_back_sg.id
}

output "back_alb_arn" {
  description = "back_alb_arn"
  value       = aws_lb.back_alb.arn
}
