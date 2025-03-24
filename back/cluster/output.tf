output "back_sg_id" {
  value = aws_security_group.back_sg.id
}

output "back_tg_name" {
  value = aws_lb_target_group.back_tg.name
}

output "back_asg_name" {
  value = aws_autoscaling_group.back_asg.name
}
