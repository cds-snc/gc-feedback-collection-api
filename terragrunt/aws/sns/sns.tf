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

# SNS topic policy to allow SES to publish
resource "aws_sns_topic_policy" "problem_topic_ses" {
  arn = module.sns_problem_topic.sns_arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSESPublish"
        Effect = "Allow"
        Principal = {
          Service = "ses.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = module.sns_problem_topic.sns_arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = var.account_id
          }
        }
      }
    ]
  })
}

resource "aws_sns_topic_policy" "toptask_topic_ses" {
  arn = module.sns_toptask_topic.sns_arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSESPublish"
        Effect = "Allow"
        Principal = {
          Service = "ses.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = module.sns_toptask_topic.sns_arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = var.account_id
          }
        }
      }
    ]
  })
}
