 variable "problem_queue_arn" {
  description = "ARN of the problem queue"
  type        = string
}

variable "toptask_queue_arn" {
  description = "ARN of the toptask queue"
  type        = string
}

variable "dto_feedback_cj_docdb_username_arn" {
  description = "ARN of SSM parameter for DocumentDB username"
  type        = string
}

variable "dto_feedback_cj_docdb_password_arn" {
  description = "ARN of SSM parameter for DocumentDB password"
  type        = string
}
