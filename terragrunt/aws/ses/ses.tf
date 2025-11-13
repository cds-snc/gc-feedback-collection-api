# SES Email Receipt Rules for feedback collection

# SES receipt rule set
resource "aws_ses_receipt_rule_set" "feedback_ruleset" {
  rule_set_name = "${var.product_name}-receipt-rules"
}

# Set as active rule set
resource "aws_ses_active_receipt_rule_set" "feedback_ruleset" {
  rule_set_name = aws_ses_receipt_rule_set.feedback_ruleset.rule_set_name
}

resource "aws_ses_receipt_rule" "problem_email" {
  name          = "${var.product_name}-problem-email-rule"
  rule_set_name = aws_ses_receipt_rule_set.feedback_ruleset.rule_set_name
  recipients    = ["problems@${var.ses_domain}"]
  enabled       = true
  scan_enabled  = true

  sns_action {
    topic_arn = var.problem_sns_topic_arn
    position  = 1
  }

  depends_on = [aws_ses_receipt_rule_set.feedback_ruleset]
}

resource "aws_ses_receipt_rule" "toptask_email" {
  name          = "${var.product_name}-toptask-email-rule"
  rule_set_name = aws_ses_receipt_rule_set.feedback_ruleset.rule_set_name
  recipients    = ["surveys@${var.ses_domain}"]
  enabled       = true
  scan_enabled  = true

  sns_action {
    topic_arn = var.toptask_sns_topic_arn
    position  = 1
  }

  depends_on = [aws_ses_receipt_rule_set.feedback_ruleset]
}

# Domain identity verification (DNS records must be added manually)
resource "aws_ses_domain_identity" "feedback_domain" {
  domain = var.ses_domain
}

# DKIM for domain (email authentication)
resource "aws_ses_domain_dkim" "feedback_domain" {
  domain = aws_ses_domain_identity.feedback_domain.domain
}

# Domain mail from (optional - for better deliverability)
resource "aws_ses_domain_mail_from" "feedback_domain" {
  domain           = aws_ses_domain_identity.feedback_domain.domain
  mail_from_domain = "mail.${var.ses_domain}"
}

# S3 bucket for storing received emails (optional backup)
resource "aws_s3_bucket" "ses_emails" {
  bucket = "${var.product_name}-ses-emails-${var.account_id}"

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

resource "aws_s3_bucket_versioning" "ses_emails" {
  bucket = aws_s3_bucket.ses_emails.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "ses_emails" {
  bucket = aws_s3_bucket.ses_emails.id

  rule {
    id     = "delete-old-emails"
    status = "Enabled"

    filter {}

    expiration {
      days = 90
    }
  }
}

# S3 bucket policy to allow SES to write
resource "aws_s3_bucket_policy" "ses_emails" {
  bucket = aws_s3_bucket.ses_emails.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSESPuts"
        Effect = "Allow"
        Principal = {
          Service = "ses.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.ses_emails.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = var.account_id
          }
        }
      }
    ]
  })
}
