output "hosted_zone_id" {
  description = "Route53 hosted zone ID that will hold our DNS records"
  value       = aws_route53_zone.feedback_collection.zone_id
}

output "custom_domain_name" {
  description = "Custom domain name for the API"
  value       = var.domain
}

output "custom_problem_form_endpoint" {
  description = "Custom domain URL for the problem form endpoint"
  value       = "https://${var.domain}/problem/form"
}

output "custom_toptask_survey_form_endpoint" {
  description = "Custom domain URL for the toptask survey form endpoint"
  value       = "https://${var.domain}/toptask/survey/form"
}

output "api_gateway_custom_domain_created" {
  description = "Whether the custom domain was created"
  value       = var.certificate_arn != "" ? true : false
}