variable "api_gateway_domain_name" {
  description = "Regional domain name from API Gateway custom domain"
  type        = string
  default     = ""
}

variable "api_gateway_hosted_zone_id" {
  description = "Hosted zone ID from API Gateway custom domain"
  type        = string
  default     = ""
}

variable "api_cert_validation_options" {
  description = "Certificate validation options from API Gateway"
  type = map(object({
    resource_record_name  = string
    resource_record_type  = string
    resource_record_value = string
  }))
  default = {}
}