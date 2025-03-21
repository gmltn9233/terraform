output "front_server_id" {
  value = aws_instance.front_server.id
}

output "front_sg_id" {
  value = aws_security_group.front_sg.id
}
