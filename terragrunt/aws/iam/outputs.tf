output "lambda_sqs_policy_arn" {
  description = "ARN of the Lambda SQS send policy"
  value       = aws_iam_policy.lambda_sqs_policy.arn
}

output "lambda_sqs_receive_policy_arn" {
  description = "ARN of the Lambda SQS receive policy"
  value       = aws_iam_policy.lambda_sqs_receive_policy.arn
}

output "lambda_ssm_policy_arn" {
  description = "ARN of the Lambda SSM parameter access policy"
  value       = aws_iam_policy.lambda_ssm_policy.arn
}
