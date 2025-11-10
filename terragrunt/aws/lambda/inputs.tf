 variable "problem_queue_url" {
  description = "URL of the problem SQS queue"
  type        = string
}

variable "problem_queue_arn" {
  description = "ARN of the problem SQS queue"
  type        = string
}

variable "toptask_queue_url" {
  description = "URL of the toptask SQS queue"
  type        = string
}

variable "toptask_queue_arn" {
  description = "ARN of the toptask SQS queue"
  type        = string
}

variable "problem_topic_arn" {
  description = "ARN of the problem SNS topic"
  type        = string
}

variable "toptask_topic_arn" {
  description = "ARN of the toptask SNS topic"
  type        = string
}

variable "api_gateway_execution_arn" {
  description = "Execution ARN of the API Gateway"
  type        = string
}

# Shared infrastructure from dto-feedback-cj
variable "dto_feedback_cj_vpc_id" {
  description = "VPC ID from dto-feedback-cj"
  type        = string
}

variable "dto_feedback_cj_vpc_private_subnet_ids" {
  description = "Private subnet IDs from dto-feedback-cj VPC"
  type        = list(string)
}

variable "dto_feedback_cj_vpc_cidr_block" {
  description = "CIDR block of the dto-feedback-cj VPC"
  type        = string
}

variable "dto_feedback_cj_docdb_endpoint" {
  description = "DocumentDB cluster endpoint from dto-feedback-cj"
  type        = string
}

variable "dto_feedback_cj_docdb_username_arn" {
  description = "ARN of DocumentDB username SSM parameter from dto-feedback-cj"
  type        = string
}

variable "dto_feedback_cj_docdb_password_arn" {
  description = "ARN of DocumentDB password SSM parameter from dto-feedback-cj"
  type        = string
}

# IAM policy ARNs (from iam module)
variable "lambda_sqs_policy_arn" {
  description = "ARN of the Lambda SQS send policy"
  type        = string
}

variable "lambda_sqs_receive_policy_arn" {
  description = "ARN of the Lambda SQS receive policy"
  type        = string
}

variable "lambda_ssm_policy_arn" {
  description = "ARN of the Lambda SSM parameter access policy"
  type        = string
}

variable "lambda_source_code_path" {
  description = "Path to the Lambda source code directory"
  type        = string
}

