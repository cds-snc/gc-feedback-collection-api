resource "aws_route53_zone" "feedback_collection" {
  name = var.domain

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

# MX record for SES email receiving
resource "aws_route53_record" "ses_mx" {
  zone_id = aws_route53_zone.feedback_collection.zone_id
  name    = var.domain
  type    = "MX"
  ttl     = 300
  records = ["10 inbound-smtp.${var.region}.amazonaws.com"]
}

# ACM certificate validation records (for API Gateway custom domain)
resource "aws_route53_record" "api_cert_validation" {
  for_each = var.api_cert_validation_options

  zone_id = aws_route53_zone.feedback_collection.zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  records = [each.value.resource_record_value]
  ttl     = 60
}

# Certificate validation resource
resource "aws_acm_certificate_validation" "api_domain" {
  count           = var.certificate_arn != "" ? 1 : 0
  certificate_arn = var.certificate_arn

  validation_record_fqdns = [for record in aws_route53_record.api_cert_validation : record.fqdn]
}

# Custom domain name for API Gateway (created after certificate validates)
resource "aws_api_gateway_domain_name" "api_domain" {
  count = var.certificate_arn != "" ? 1 : 0

  domain_name              = var.domain
  regional_certificate_arn = var.certificate_arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }

  depends_on = [aws_acm_certificate_validation.api_domain]
}

# Base path mapping for custom domain
resource "aws_api_gateway_base_path_mapping" "api_domain" {
  count = var.certificate_arn != "" && var.api_gateway_id != "" ? 1 : 0

  api_id      = var.api_gateway_id
  stage_name  = var.api_gateway_stage_name
  domain_name = aws_api_gateway_domain_name.api_domain[0].domain_name
}

# A record for API Gateway custom domain
resource "aws_route53_record" "api_gateway" {
  count   = var.certificate_arn != "" ? 1 : 0
  zone_id = aws_route53_zone.feedback_collection.zone_id
  name    = var.domain
  type    = "A"

  alias {
    name                   = aws_api_gateway_domain_name.api_domain[0].regional_domain_name
    zone_id                = aws_api_gateway_domain_name.api_domain[0].regional_zone_id
    evaluate_target_health = false
  }
}