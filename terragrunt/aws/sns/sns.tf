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
