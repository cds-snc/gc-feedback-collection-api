variable "ses_domain" {
  description = "Domain for SES email receipt (e.g., alpha.canada.ca)"
  type        = string
  default     = "alpha.canada.ca"
}

variable "problem_sns_topic_arn" {
  description = "ARN of the problem SNS topic"
  type        = string
}

variable "toptask_sns_topic_arn" {
  description = "ARN of the toptask SNS topic"
  type        = string
}
