# Data source to construct the SNS topic policy for SES access
data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    sid    = "AllowAccountOwner"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }
    actions   = ["SNS:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowSESPublish"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ses.amazonaws.com"]
    }
    actions   = ["SNS:Publish"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [var.account_id]
    }
  }
}

# Problem email SNS topic (receives from SES)
module "sns_problem_topic" {
  source = "github.com/cds-snc/terraform-modules//sns?ref=v10.8.5"

  name              = "${var.product_name}-problem-topic"
  billing_tag_key   = "CostCentre"
  billing_tag_value = var.billing_code
  kms_event_sources = ["ses.amazonaws.com"]
  policy            = data.aws_iam_policy_document.sns_topic_policy.json
}

# TopTask survey SNS topic (receives from SES)
module "sns_toptask_topic" {
  source = "github.com/cds-snc/terraform-modules//sns?ref=v10.8.5"

  name              = "${var.product_name}-toptask-topic"
  billing_tag_key   = "CostCentre"
  billing_tag_value = var.billing_code
  kms_event_sources = ["ses.amazonaws.com"]
  policy            = data.aws_iam_policy_document.sns_topic_policy.json
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
