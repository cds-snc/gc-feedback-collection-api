variable "api_cert_validation_options" {
  description = "Certificate validation options from API Gateway"
  type = map(object({
    resource_record_name  = string
    resource_record_type  = string
    resource_record_value = string
  }))
  default = {}
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate from API Gateway"
  type        = string
  default     = ""
}

variable "api_gateway_id" {
  description = "ID of the API Gateway REST API"
  type        = string
  default     = ""
}

variable "api_gateway_stage_name" {
  description = "Name of the API Gateway stage"
  type        = string
  default     = ""
}