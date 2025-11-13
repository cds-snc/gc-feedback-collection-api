module "sns_problem_topic" {
  source = "github.com/cds-snc/terraform-modules//sns?ref=v10.8.5"

  name              = "${var.product_name}-problem-topic"
  billing_tag_key   = "CostCentre"
  billing_tag_value = var.billing_code
  kms_event_sources = ["ses.amazonaws.com"]
}

# TopTask survey SNS topic (receives from SES)
module "sns_toptask_topic" {
  source = "github.com/cds-snc/terraform-modules//sns?ref=v10.8.5"

  name              = "${var.product_name}-toptask-topic"
  billing_tag_key   = "CostCentre"
  billing_tag_value = var.billing_code
  kms_event_sources = ["ses.amazonaws.com"]
}
