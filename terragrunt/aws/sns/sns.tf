# KMS key for SNS topic encryption with correct SES permissions
resource "aws_kms_key" "sns_encryption" {
  description             = "KMS key for SNS topic encryption (SES compatible)"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

resource "aws_kms_alias" "sns_encryption" {
  name          = "alias/${var.product_name}-sns-encryption"
  target_key_id = aws_kms_key.sns_encryption.key_id
}

# KMS key policy with correct SES permissions
data "aws_iam_policy_document" "kms_key_policy" {
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "Allow SES to use the key"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ses.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [var.account_id]
    }
  }
}

resource "aws_kms_key_policy" "sns_encryption" {
  key_id = aws_kms_key.sns_encryption.id
  policy = data.aws_iam_policy_document.kms_key_policy.json
}

# Data source to construct the SNS topic policy for SES access
data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    sid    = "AllowAccountOwner"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }
    actions = [
      "SNS:GetTopicAttributes",
      "SNS:SetTopicAttributes",
      "SNS:AddPermission",
      "SNS:RemovePermission",
      "SNS:DeleteTopic",
      "SNS:Subscribe",
      "SNS:ListSubscriptionsByTopic",
      "SNS:Publish"
    ]
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
  kms_master_key_id = aws_kms_key.sns_encryption.id
  policy            = data.aws_iam_policy_document.sns_topic_policy.json
}

# TopTask survey SNS topic (receives from SES)
module "sns_toptask_topic" {
  source = "github.com/cds-snc/terraform-modules//sns?ref=v10.8.5"

  name              = "${var.product_name}-toptask-topic"
  billing_tag_key   = "CostCentre"
  billing_tag_value = var.billing_code
  kms_master_key_id = aws_kms_key.sns_encryption.id
  policy            = data.aws_iam_policy_document.sns_topic_policy.json
}
