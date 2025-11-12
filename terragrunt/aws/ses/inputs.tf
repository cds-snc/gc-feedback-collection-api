variable "ses_domain" {
  description = "Domain for SES email receipt (e.g., feedback.canada.gc.ca)"
  type        = string
  default     = "feedback.canada.gc.ca"
}

variable "problem_sns_topic_arn" {
  description = "ARN of the problem SNS topic"
  type        = string
}

variable "toptask_sns_topic_arn" {
  description = "ARN of the toptask SNS topic"
  type        = string
}
