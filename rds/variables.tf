variable "db_username" {
  type        = string
  description = "RDS DB username"
}

variable "db_password" {
  type        = string
  description = "RDS DB password"
  sensitive   = true
}
