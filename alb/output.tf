output "alb_sg" {
  description = "alb_sg"
  value       = aws_security_group.alb_sg.id
}

output "front_alb_arn" {
  description = "front_alb_id"
  value       = aws_lb.front_alb.arn
}
