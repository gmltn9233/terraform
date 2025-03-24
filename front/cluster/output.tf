output "front_sg_id" {
  value = aws_security_group.front_sg.id
}

output "front_tg_name" {
  value = aws_lb_target_group.front_tg.name
}

output "front_asg_name" {
  value = aws_autoscaling_group.front_asg.name
}
