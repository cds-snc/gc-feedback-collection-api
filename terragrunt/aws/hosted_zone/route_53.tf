resource "aws_route53_zone" "feedback_collection" {
  name = var.domain

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

# A record for API Gateway custom domain (to be added after API Gateway module creates the domain)
resource "aws_route53_record" "api_gateway" {
  count   = var.api_gateway_domain_name != "" ? 1 : 0
  zone_id = aws_route53_zone.feedback_collection.zone_id
  name    = var.domain
  type    = "A"

  alias {
    name                   = var.api_gateway_domain_name
    zone_id                = var.api_gateway_hosted_zone_id
    evaluate_target_health = false
  }
}

# ACM certificate validation records (for API Gateway)
resource "aws_route53_record" "api_cert_validation" {
  for_each = var.api_cert_validation_options

  zone_id = aws_route53_zone.feedback_collection.zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  records = [each.value.resource_record_value]
  ttl     = 60
}