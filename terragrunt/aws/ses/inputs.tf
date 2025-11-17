variable "ses_domain" {
  description = "Domain for SES email receipt (e.g., feedback-collection.cdssandbox.xyz for staging, feedback-collection.alpha.canada.ca for production)"
  type        = string
}

variable "problem_sns_topic_arn" {
  description = "ARN of the problem SNS topic"
  type        = string
}

variable "toptask_sns_topic_arn" {
  description = "ARN of the toptask SNS topic"
  type        = string
}
