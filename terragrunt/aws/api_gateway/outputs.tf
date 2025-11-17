output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = aws_api_gateway_rest_api.feedback_api.id
}

output "api_gateway_execution_arn" {
  description = "Execution ARN of the API Gateway"
  value       = aws_api_gateway_rest_api.feedback_api.execution_arn
}

output "api_gateway_invoke_url" {
  description = "Invoke URL of the API Gateway"
  value       = aws_api_gateway_stage.feedback_api.invoke_url
}

output "api_gateway_stage_name" {
  description = "Name of the API Gateway stage"
  value       = aws_api_gateway_stage.feedback_api.stage_name
}

output "problem_form_endpoint" {
  description = "Full URL for the problem form endpoint"
  value       = "${aws_api_gateway_stage.feedback_api.invoke_url}/problem/form"
}

output "toptask_survey_form_endpoint" {
  description = "Full URL for the toptask survey form endpoint"
  value       = "${aws_api_gateway_stage.feedback_api.invoke_url}/toptask/survey/form"
}

output "certificate_arn" {
  description = "ARN of the ACM certificate for custom domain"
  value       = aws_acm_certificate.api_domain.arn
}

output "certificate_validation_options" {
  description = "Certificate validation options for DNS records"
  value = {
    for dvo in aws_acm_certificate.api_domain.domain_validation_options : dvo.domain_name => {
      resource_record_name  = dvo.resource_record_name
      resource_record_type  = dvo.resource_record_type
      resource_record_value = dvo.resource_record_value
    }
  }
}
