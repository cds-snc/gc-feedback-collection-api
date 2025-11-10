variable "problem_sns_topic_arn" {
  description = "ARN of the problem SNS topic that will send messages to the queue"
  type        = string
}

variable "toptask_sns_topic_arn" {
  description = "ARN of the toptask SNS topic that will send messages to the queue"
  type        = string
}
