output "problem_queue_url" {
  description = "URL of the problem SQS queue"
  value       = aws_sqs_queue.problem_queue.url
}

output "problem_queue_arn" {
  description = "ARN of the problem SQS queue"
  value       = aws_sqs_queue.problem_queue.arn
}

output "problem_queue_dlq_arn" {
  description = "ARN of the problem SQS dead letter queue"
  value       = aws_sqs_queue.problem_queue_dlq.arn
}

output "toptask_queue_url" {
  description = "URL of the toptask SQS queue"
  value       = aws_sqs_queue.toptask_queue.url
}

output "toptask_queue_arn" {
  description = "ARN of the toptask SQS queue"
  value       = aws_sqs_queue.toptask_queue.arn
}

output "toptask_queue_dlq_arn" {
  description = "ARN of the toptask SQS dead letter queue"
  value       = aws_sqs_queue.toptask_queue_dlq.arn
}
