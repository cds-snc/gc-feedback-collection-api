output "lambda_queue_problem_arn" {
  description = "ARN of the queue_problem Lambda function"
  value       = aws_lambda_function.queue_problem.arn
}

output "lambda_queue_problem_invoke_arn" {
  description = "Invoke ARN of the queue_problem Lambda function (for API Gateway)"
  value       = aws_lambda_function.queue_problem.invoke_arn
}

output "lambda_queue_problem_form_arn" {
  description = "ARN of the queue_problem_form Lambda function"
  value       = aws_lambda_function.queue_problem_form.arn
}

output "lambda_queue_problem_form_invoke_arn" {
  description = "Invoke ARN of the queue_problem_form Lambda function (for API Gateway)"
  value       = aws_lambda_function.queue_problem_form.invoke_arn
}

output "lambda_queue_toptask_arn" {
  description = "ARN of the queue_toptask Lambda function"
  value       = aws_lambda_function.queue_toptask.arn
}

output "lambda_queue_toptask_invoke_arn" {
  description = "Invoke ARN of the queue_toptask Lambda function (for API Gateway)"
  value       = aws_lambda_function.queue_toptask.invoke_arn
}

output "lambda_queue_toptask_survey_form_arn" {
  description = "ARN of the queue_toptask_survey_form Lambda function"
  value       = aws_lambda_function.queue_toptask_survey_form.arn
}

output "lambda_queue_toptask_survey_form_invoke_arn" {
  description = "Invoke ARN of the queue_toptask_survey_form Lambda function (for API Gateway)"
  value       = aws_lambda_function.queue_toptask_survey_form.invoke_arn
}

output "problem_commit_lambda_arn" {
  description = "ARN of the problem_commit Lambda function"
  value       = aws_lambda_function.problem_commit.arn
}

output "top_task_survey_commit_lambda_arn" {
  description = "ARN of the top_task_survey_commit Lambda function"
  value       = aws_lambda_function.toptask_survey_commit.arn
}

output "queue_problem_lambda_name" {
  description = "Name of the queue_problem Lambda function"
  value       = aws_lambda_function.queue_problem.function_name
}

output "queue_problem_form_lambda_name" {
  description = "Name of the queue_problem_form Lambda function"
  value       = aws_lambda_function.queue_problem_form.function_name
}

output "queue_toptask_lambda_name" {
  description = "Name of the queue_toptask Lambda function"
  value       = aws_lambda_function.queue_toptask.function_name
}

output "queue_toptask_survey_form_lambda_name" {
  description = "Name of the queue_toptask_survey_form Lambda function"
  value       = aws_lambda_function.queue_toptask_survey_form.function_name
}

output "problem_commit_lambda_name" {
  description = "Name of the problem_commit Lambda function"
  value       = aws_lambda_function.problem_commit.function_name
}

output "top_task_survey_commit_lambda_name" {
  description = "Name of the top_task_survey_commit Lambda function"
  value       = aws_lambda_function.toptask_survey_commit.function_name
}

output "lambda_security_group_id" {
  description = "Security group ID for Lambda functions"
  value       = aws_security_group.lambda_sg.id
}
