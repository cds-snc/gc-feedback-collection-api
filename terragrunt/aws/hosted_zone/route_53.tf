resource "aws_route53_zone" "feedback_collection" {
  name = var.domain

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}