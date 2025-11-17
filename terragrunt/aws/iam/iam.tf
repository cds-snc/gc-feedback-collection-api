# IAM policies for Lambda functions in feedback collection API

# Policy document for Lambda to send messages to SQS
data "aws_iam_policy_document" "lambda_sqs_policy" {
  statement {
    effect = "Allow"
    actions = [
      "sqs:SendMessage",
      "sqs:GetQueueUrl"
    ]
    resources = [
      var.problem_queue_arn,
      var.toptask_queue_arn
    ]
  }
}

# Policy document for Lambda to receive messages from SQS
data "aws_iam_policy_document" "lambda_sqs_receive_policy" {
  statement {
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = [
      var.problem_queue_arn,
      var.toptask_queue_arn
    ]
  }
}

# Policy document for Lambda to read SSM parameters (DocumentDB credentials)
data "aws_iam_policy_document" "lambda_ssm_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters"
    ]
    resources = [
      var.dto_feedback_cj_docdb_username_arn,
      var.dto_feedback_cj_docdb_password_arn
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ssm.ca-central-1.amazonaws.com"]
    }
  }
}

# IAM Policy: Lambda SQS send permissions
resource "aws_iam_policy" "lambda_sqs_policy" {
  name        = "${var.product_name}-lambda-sqs-policy"
  description = "Allow Lambda to send messages to SQS"
  policy      = data.aws_iam_policy_document.lambda_sqs_policy.json

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

# IAM Policy: Lambda SQS receive permissions
resource "aws_iam_policy" "lambda_sqs_receive_policy" {
  name        = "${var.product_name}-lambda-sqs-receive-policy"
  description = "Allow Lambda to receive messages from SQS"
  policy      = data.aws_iam_policy_document.lambda_sqs_receive_policy.json

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

# IAM Policy: Lambda SSM parameter access
resource "aws_iam_policy" "lambda_ssm_policy" {
  name        = "${var.product_name}-lambda-ssm-policy"
  description = "Allow Lambda to read SSM parameters for DocumentDB credentials"
  policy      = data.aws_iam_policy_document.lambda_ssm_policy.json

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}
