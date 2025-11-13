output "ses_domain_identity_arn" {
  description = "ARN of the SES domain identity"
  value       = aws_ses_domain_identity.feedback_domain.arn
}

output "ses_domain_verification_token" {
  description = "Verification token for SES domain (add as TXT record in DNS)"
  value       = aws_ses_domain_identity.feedback_domain.verification_token
}

output "ses_dkim_tokens" {
  description = "DKIM tokens for domain (add as CNAME records in DNS)"
  value       = aws_ses_domain_dkim.feedback_domain.dkim_tokens
}

output "ses_mail_from_domain" {
  description = "Mail from domain for SES"
  value       = aws_ses_domain_mail_from.feedback_domain.mail_from_domain
}

output "ses_emails_bucket" {
  description = "S3 bucket for storing received emails"
  value       = aws_s3_bucket.ses_emails.bucket
}

output "problem_email_address" {
  description = "Email address for problem reports"
  value       = "problems@${var.ses_domain}"
}

output "survey_email_address" {
  description = "Email address for survey responses"
  value       = "surveys@${var.ses_domain}"
}
