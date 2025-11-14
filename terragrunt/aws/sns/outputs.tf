output "problem_topic_arn" {
  description = "ARN of the problem SNS topic"
  value       = module.sns_problem_topic.sns_arn
}

output "toptask_topic_arn" {
  description = "ARN of the toptask SNS topic"
  value       = module.sns_toptask_topic.sns_arn
}

output "problem_topic_name" {
  description = "Name of the problem SNS topic"
  value       = module.sns_problem_topic.sns_id
}

output "toptask_topic_name" {
  description = "Name of the toptask SNS topic"
  value       = module.sns_toptask_topic.sns_id
}

output "kms_key_id" {
  description = "KMS key ID for SNS encryption"
  value       = aws_kms_key.sns_encryption.id
}

output "kms_key_arn" {
  description = "KMS key ARN for SNS encryption"
  value       = aws_kms_key.sns_encryption.arn
}
