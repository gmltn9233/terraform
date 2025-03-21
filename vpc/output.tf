output "vpc_id" {
  description = "VPC-id"
  value = aws_vpc.my_vpc.id
}

output "pub_sub_A_id" {
  description = "AZ-a의 Public 서브넷 ID (OpenVPN 용)"
  value       = aws_subnet.pub_sub_A.id
}

output "nat_sub_1_A_id" {
  description = "AZ-a의 NAT 서브넷 1 ID (프론트 서버용)"
  value       = aws_subnet.nat_sub_1_A.id
}

output "nat_sub_2_A_id" {
  description = "AZ-a의 NAT 서브넷 2 ID (백서버용)"
  value       = aws_subnet.nat_sub_2_A.id
}

output "prv_sub_A_id" {
  description = "AZ-a의 프라이빗 서브넷 ID (RDS 용)"
  value       = aws_subnet.prv_sub_A.id
}

output "pub_sub_C_id" {
  description = "AZ-c의 Public 서브넷 ID (OpenVPN 용)"
  value       = aws_subnet.pub_sub_C.id
}

output "nat_sub_1_C_id" {
  description = "AZ-c의 NAT 서브넷 1 ID (프론트 서버용)"
  value       = aws_subnet.nat_sub_1_C.id
}

output "nat_sub_2_C_id" {
  description = "AZ-c의 NAT 서브넷 2 ID (백서버용)"
  value       = aws_subnet.nat_sub_2_C.id
}

output "prv_sub_C_id" {
  description = "AZ-c의 프라이빗 서브넷 ID (RDS 용)"
  value       = aws_subnet.prv_sub_C.id
}
