variable "cert_arn" {
  type        = string
  description = "cert arn"
  sensitive   = true
}

variable "custom_dns" {
  type      = string
  default   = "custom dns"
  sensitive = true
}
