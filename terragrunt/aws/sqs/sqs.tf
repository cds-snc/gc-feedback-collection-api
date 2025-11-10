# SQS Queues for feedback collection API

# Problem feedback queue
resource "aws_sqs_queue" "problem_queue_dlq" {
  name                      = "${var.product_name}-problem-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

resource "aws_sqs_queue" "problem_queue" {
  name                       = "${var.product_name}-problem-queue"
  visibility_timeout_seconds = 300    # 5 minutes for Lambda processing
  message_retention_seconds  = 345600 # 4 days
  receive_wait_time_seconds  = 0      # Short polling for faster processing

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.problem_queue_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

# TopTask survey queue
resource "aws_sqs_queue" "toptask_queue_dlq" {
  name                      = "${var.product_name}-toptask-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

resource "aws_sqs_queue" "toptask_queue" {
  name                       = "${var.product_name}-toptask-queue"
  visibility_timeout_seconds = 300    # 5 minutes for Lambda processing
  message_retention_seconds  = 345600 # 4 days
  receive_wait_time_seconds  = 0      # Short polling for faster processing

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.toptask_queue_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

# SQS Queue Policies to allow SNS to send messages
resource "aws_sqs_queue_policy" "problem_queue_policy" {
  queue_url = aws_sqs_queue.problem_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.problem_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = var.problem_sns_topic_arn
          }
        }
      }
    ]
  })
}

resource "aws_sqs_queue_policy" "toptask_queue_policy" {
  queue_url = aws_sqs_queue.toptask_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.toptask_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = var.toptask_sns_topic_arn
          }
        }
      }
    ]
  })
}

# SNS to SQS subscriptions (created in SQS module to avoid circular dependencies)
resource "aws_sns_topic_subscription" "problem_to_queue" {
  topic_arn = var.problem_sns_topic_arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.problem_queue.arn
}

resource "aws_sns_topic_subscription" "toptask_to_queue" {
  topic_arn = var.toptask_sns_topic_arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.toptask_queue.arn
}
