output "alb_front_sg" {
  description = "alb_front_sg"
  value       = aws_security_group.alb_front_sg.id
}

output "front_alb_arn" {
  description = "front_alb_arn"
  value       = aws_lb.front_alb.arn
}
