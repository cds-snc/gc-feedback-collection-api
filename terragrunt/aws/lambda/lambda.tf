# Lambda functions for feedback collection API using CDS terraform-modules

# Note: Using ZIP-based deployment for simplicity and less overhead
# ZIP files are created from the src/ directory

# Data source to create ZIP archives for Lambda functions
data "archive_file" "queue_problem" {
  type        = "zip"
  source_dir  = var.lambda_source_code_path
  output_path = "${path.module}/.terraform/lambda-queue-problem.zip"
  excludes    = ["__pycache__", "*.pyc", ".pytest_cache", "tests"]
}

data "archive_file" "queue_problem_form" {
  type        = "zip"
  source_dir  = var.lambda_source_code_path
  output_path = "${path.module}/.terraform/lambda-queue-problem-form.zip"
  excludes    = ["__pycache__", "*.pyc", ".pytest_cache", "tests"]
}

data "archive_file" "queue_toptask" {
  type        = "zip"
  source_dir  = var.lambda_source_code_path
  output_path = "${path.module}/.terraform/lambda-queue-toptask.zip"
  excludes    = ["__pycache__", "*.pyc", ".pytest_cache", "tests"]
}

data "archive_file" "queue_toptask_survey_form" {
  type        = "zip"
  source_dir  = var.lambda_source_code_path
  output_path = "${path.module}/.terraform/lambda-queue-toptask-survey-form.zip"
  excludes    = ["__pycache__", "*.pyc", ".pytest_cache", "tests"]
}

# Build problem_commit Lambda with dependencies
resource "null_resource" "problem_commit_build" {
  triggers = {
    source_hash = sha256(join("", [
      for f in fileset(var.lambda_source_code_path, "**") :
      filesha256("${var.lambda_source_code_path}/${f}")
    ]))
    requirements_hash = filesha256("${var.lambda_source_code_path}/requirements.txt")
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      PACKAGE_DIR="${path.module}/.terraform/builds/problem-commit"
      ZIP_FILE="${path.module}/.terraform/lambda-problem-commit.zip"

      # Clean up previous builds
      rm -rf "$PACKAGE_DIR"
      rm -f "$ZIP_FILE"
      mkdir -p "$PACKAGE_DIR"

      # Install dependencies to package directory (at root level)
      # Explicitly request CPython 3.11 manylinux wheels for x86_64
      pip install -r ${var.lambda_source_code_path}/requirements.txt \
        --target "$PACKAGE_DIR" \
        --upgrade \
        --platform manylinux2014_x86_64 \
        --implementation cp \
        --python-version 3.11 \
        --only-binary=:all:

      # Copy source files (recursive) so packages and data files are included
      # Exclude caches, tests and pyc files
      rsync -a ${var.lambda_source_code_path}/ "$PACKAGE_DIR/" --exclude="__pycache__" --exclude="*.pyc" --exclude=".pytest_cache" --exclude="tests"

      # Ensure reasonable permissions for Lambda
      find "$PACKAGE_DIR" -type f -exec chmod 644 {} +
      find "$PACKAGE_DIR" -type d -exec chmod 755 {} +

      # Create ZIP with everything at root
      cd "$PACKAGE_DIR"
      zip -r "$ZIP_FILE" . -x "__pycache__/*" "*.pyc"
    EOT
  }
}

# Build toptask_survey_commit Lambda with dependencies
resource "null_resource" "toptask_survey_commit_build" {
  triggers = {
    source_hash = sha256(join("", [
      for f in fileset(var.lambda_source_code_path, "**") :
      filesha256("${var.lambda_source_code_path}/${f}")
    ]))
    requirements_hash = filesha256("${var.lambda_source_code_path}/requirements.txt")
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      PACKAGE_DIR="${path.module}/.terraform/builds/toptask-survey-commit"
      ZIP_FILE="${path.module}/.terraform/lambda-toptask-survey-commit.zip"

      # Clean up previous builds
      rm -rf "$PACKAGE_DIR"
      rm -f "$ZIP_FILE"
      mkdir -p "$PACKAGE_DIR"

      # Install dependencies to package directory (at root level)
      # Explicitly request CPython 3.11 manylinux wheels for x86_64
      pip install -r ${var.lambda_source_code_path}/requirements.txt \
        --target "$PACKAGE_DIR" \
        --upgrade \
        --platform manylinux2014_x86_64 \
        --implementation cp \
        --python-version 3.11 \
        --only-binary=:all:

      # Copy source files (recursive) so packages and data files are included
      # Exclude caches, tests and pyc files
      rsync -a ${var.lambda_source_code_path}/ "$PACKAGE_DIR/" --exclude="__pycache__" --exclude="*.pyc" --exclude=".pytest_cache" --exclude="tests"

      # Ensure reasonable permissions for Lambda
      find "$PACKAGE_DIR" -type f -exec chmod 644 {} +
      find "$PACKAGE_DIR" -type d -exec chmod 755 {} +

      # Create ZIP with everything at root
      cd "$PACKAGE_DIR"
      zip -r "$ZIP_FILE" . -x "__pycache__/*" "*.pyc"
    EOT
  }
}

# Security group for Lambda functions in VPC (shared by all Lambda functions)
resource "aws_security_group" "lambda_sg" {
  name        = "${var.product_name}-lambda-sg"
  description = "Security group for Lambda functions accessing DocumentDB"
  vpc_id      = var.dto_feedback_cj_vpc_id

  # Outbound to DocumentDB (port 27017)
  egress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = [var.dto_feedback_cj_vpc_cidr_block]
    description = "Allow Lambda to connect to DocumentDB"
  }

  # Outbound HTTPS for AWS services (SQS, SNS, SES, SSM)
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow Lambda to call AWS APIs"
  }

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

# 1. queue_problem Lambda (SNS → SQS)
resource "aws_lambda_function" "queue_problem" {
  function_name    = "${var.product_name}-queue-problem"
  filename         = data.archive_file.queue_problem.output_path
  source_code_hash = data.archive_file.queue_problem.output_base64sha256
  handler          = "queue_problem.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 256
  role             = aws_iam_role.queue_problem_lambda.arn

  environment {
    variables = {
      PROBLEM_QUEUE_URL = var.problem_queue_url
      ENVIRONMENT       = var.env
    }
  }

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

resource "aws_iam_role" "queue_problem_lambda" {
  name = "${var.product_name}-queue-problem-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

resource "aws_iam_role_policy_attachment" "queue_problem_sqs" {
  role       = aws_iam_role.queue_problem_lambda.name
  policy_arn = var.lambda_sqs_policy_arn
}

resource "aws_iam_role_policy_attachment" "queue_problem_logs" {
  role       = aws_iam_role.queue_problem_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "queue_problem" {
  name              = "/aws/lambda/${var.product_name}-queue-problem"
  retention_in_days = 30

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

resource "aws_lambda_permission" "queue_problem_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.queue_problem.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = var.problem_topic_arn
}

resource "aws_sns_topic_subscription" "problem_to_lambda" {
  topic_arn = var.problem_topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.queue_problem.arn
}

# 2. queue_problem_form Lambda (API Gateway → SQS)
resource "aws_lambda_function" "queue_problem_form" {
  function_name    = "${var.product_name}-queue-problem-form"
  filename         = data.archive_file.queue_problem_form.output_path
  source_code_hash = data.archive_file.queue_problem_form.output_base64sha256
  handler          = "queue_problem_form.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 256
  role             = aws_iam_role.queue_problem_form_lambda.arn

  environment {
    variables = {
      PROBLEM_QUEUE_URL = var.problem_queue_url
      ENVIRONMENT       = var.env
    }
  }

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

resource "aws_iam_role" "queue_problem_form_lambda" {
  name = "${var.product_name}-queue-problem-form-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

resource "aws_iam_role_policy_attachment" "queue_problem_form_sqs" {
  role       = aws_iam_role.queue_problem_form_lambda.name
  policy_arn = var.lambda_sqs_policy_arn
}

resource "aws_iam_role_policy_attachment" "queue_problem_form_logs" {
  role       = aws_iam_role.queue_problem_form_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "queue_problem_form" {
  name              = "/aws/lambda/${var.product_name}-queue-problem-form"
  retention_in_days = 30

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

# 3. queue_toptask Lambda (SNS → SQS)
resource "aws_lambda_function" "queue_toptask" {
  function_name    = "${var.product_name}-queue-toptask"
  filename         = data.archive_file.queue_toptask.output_path
  source_code_hash = data.archive_file.queue_toptask.output_base64sha256
  handler          = "queue_toptask.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 256
  role             = aws_iam_role.queue_toptask_lambda.arn

  environment {
    variables = {
      TOPTASK_QUEUE_URL = var.toptask_queue_url
      ENVIRONMENT       = var.env
    }
  }

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

resource "aws_iam_role" "queue_toptask_lambda" {
  name = "${var.product_name}-queue-toptask-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

resource "aws_iam_role_policy_attachment" "queue_toptask_sqs" {
  role       = aws_iam_role.queue_toptask_lambda.name
  policy_arn = var.lambda_sqs_policy_arn
}

resource "aws_iam_role_policy_attachment" "queue_toptask_logs" {
  role       = aws_iam_role.queue_toptask_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "queue_toptask" {
  name              = "/aws/lambda/${var.product_name}-queue-toptask"
  retention_in_days = 30

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

resource "aws_lambda_permission" "queue_toptask_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.queue_toptask.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = var.toptask_topic_arn
}

resource "aws_sns_topic_subscription" "toptask_to_lambda" {
  topic_arn = var.toptask_topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.queue_toptask.arn
}

# 4. queue_toptask_survey_form Lambda (API Gateway → SQS)
resource "aws_lambda_function" "queue_toptask_survey_form" {
  function_name    = "${var.product_name}-queue-toptask-survey-form"
  filename         = data.archive_file.queue_toptask_survey_form.output_path
  source_code_hash = data.archive_file.queue_toptask_survey_form.output_base64sha256
  handler          = "queue_toptask_survey_form.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 256
  role             = aws_iam_role.queue_toptask_survey_form_lambda.arn

  environment {
    variables = {
      TOPTASK_QUEUE_URL = var.toptask_queue_url
      ENVIRONMENT       = var.env
    }
  }

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

resource "aws_iam_role" "queue_toptask_survey_form_lambda" {
  name = "${var.product_name}-queue-toptask-survey-form-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

resource "aws_iam_role_policy_attachment" "queue_toptask_survey_form_sqs" {
  role       = aws_iam_role.queue_toptask_survey_form_lambda.name
  policy_arn = var.lambda_sqs_policy_arn
}

resource "aws_iam_role_policy_attachment" "queue_toptask_survey_form_logs" {
  role       = aws_iam_role.queue_toptask_survey_form_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "queue_toptask_survey_form" {
  name              = "/aws/lambda/${var.product_name}-queue-toptask-survey-form"
  retention_in_days = 30

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

# 5. problem_commit Lambda (EventBridge → SQS → DocumentDB)
resource "aws_lambda_function" "problem_commit" {
  function_name    = "${var.product_name}-problem-commit"
  filename         = "${path.module}/.terraform/lambda-problem-commit.zip"
  source_code_hash = filebase64sha256("${path.module}/.terraform/lambda-problem-commit.zip")
  handler          = "problem_commit.lambda_handler"
  runtime          = "python3.11"
  timeout          = 300 # 5 minutes for batch processing
  memory_size      = 512
  role             = aws_iam_role.problem_commit_lambda.arn

  environment {
    variables = {
      PROBLEM_QUEUE_URL    = var.problem_queue_url
      MONGO_URL            = var.dto_feedback_cj_docdb_endpoint
      MONGO_PORT           = "27017"
      MONGO_DB             = "pagesuccess"
      MONGO_USERNAME_PARAM = var.dto_feedback_cj_docdb_username_arn
      MONGO_PASSWORD_PARAM = var.dto_feedback_cj_docdb_password_arn
      ENVIRONMENT          = var.env
    }
  }

  vpc_config {
    subnet_ids         = var.dto_feedback_cj_vpc_private_subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
  
  depends_on = [null_resource.problem_commit_build]
}

# IAM role for problem_commit Lambda
resource "aws_iam_role" "problem_commit_lambda" {
  name = "${var.product_name}-problem-commit-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

# Attach policies to problem_commit Lambda role
resource "aws_iam_role_policy_attachment" "problem_commit_sqs" {
  role       = aws_iam_role.problem_commit_lambda.name
  policy_arn = var.lambda_sqs_receive_policy_arn
}

resource "aws_iam_role_policy_attachment" "problem_commit_ssm" {
  role       = aws_iam_role.problem_commit_lambda.name
  policy_arn = var.lambda_ssm_policy_arn
}

# Attach VPC execution policy for problem_commit Lambda
resource "aws_iam_role_policy_attachment" "problem_commit_vpc" {
  role       = aws_iam_role.problem_commit_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# CloudWatch Log Group for problem_commit Lambda
resource "aws_cloudwatch_log_group" "problem_commit" {
  name              = "/aws/lambda/${var.product_name}-problem-commit"
  retention_in_days = 30

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

# EventBridge rule to trigger problem_commit Lambda every 2 minutes
resource "aws_cloudwatch_event_rule" "problem_commit_schedule" {
  name                = "${var.product_name}-problem-commit-schedule"
  description         = "Trigger problem_commit Lambda every 2 minutes"
  schedule_expression = "rate(2 minutes)"

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

resource "aws_cloudwatch_event_target" "problem_commit_schedule" {
  rule      = aws_cloudwatch_event_rule.problem_commit_schedule.name
  target_id = "problem-commit-lambda"
  arn       = aws_lambda_function.problem_commit.arn
}

resource "aws_lambda_permission" "problem_commit_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.problem_commit.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.problem_commit_schedule.arn
}

# 6. top_task_survey_commit Lambda (EventBridge → SQS → DocumentDB)
resource "aws_lambda_function" "toptask_survey_commit" {
  function_name    = "${var.product_name}-toptask-survey-commit"
  filename         = "${path.module}/.terraform/lambda-toptask-survey-commit.zip"
  source_code_hash = filebase64sha256("${path.module}/.terraform/lambda-toptask-survey-commit.zip")
  handler          = "top_task_survey_commit.lambda_handler"
  runtime          = "python3.11"
  timeout          = 300 # 5 minutes for batch processing
  memory_size      = 512
  role             = aws_iam_role.toptask_survey_commit_lambda.arn

  environment {
    variables = {
      TOPTASK_QUEUE_URL    = var.toptask_queue_url
      MONGO_URL            = var.dto_feedback_cj_docdb_endpoint
      MONGO_PORT           = "27017"
      MONGO_DB             = "pagesuccess"
      MONGO_USERNAME_PARAM = var.dto_feedback_cj_docdb_username_arn
      MONGO_PASSWORD_PARAM = var.dto_feedback_cj_docdb_password_arn
      ENVIRONMENT          = var.env
    }
  }

  vpc_config {
    subnet_ids         = var.dto_feedback_cj_vpc_private_subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
  
  depends_on = [null_resource.toptask_survey_commit_build]
}

# IAM role for toptask_survey_commit Lambda
resource "aws_iam_role" "toptask_survey_commit_lambda" {
  name = "${var.product_name}-toptask-survey-commit-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

# Attach policies to toptask_survey_commit Lambda role
resource "aws_iam_role_policy_attachment" "toptask_survey_commit_sqs" {
  role       = aws_iam_role.toptask_survey_commit_lambda.name
  policy_arn = var.lambda_sqs_receive_policy_arn
}

resource "aws_iam_role_policy_attachment" "toptask_survey_commit_ssm" {
  role       = aws_iam_role.toptask_survey_commit_lambda.name
  policy_arn = var.lambda_ssm_policy_arn
}

# Attach VPC execution policy for toptask_survey_commit Lambda
resource "aws_iam_role_policy_attachment" "toptask_survey_commit_vpc" {
  role       = aws_iam_role.toptask_survey_commit_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# CloudWatch Log Group for toptask_survey_commit Lambda
resource "aws_cloudwatch_log_group" "toptask_survey_commit" {
  name              = "/aws/lambda/${var.product_name}-toptask-survey-commit"
  retention_in_days = 30

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

# EventBridge rule to trigger toptask_survey_commit Lambda every 2 minutes
resource "aws_cloudwatch_event_rule" "toptask_survey_commit_schedule" {
  name                = "${var.product_name}-toptask-survey-commit-schedule"
  description         = "Trigger toptask_survey_commit Lambda every 2 minutes"
  schedule_expression = "rate(2 minutes)"

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

resource "aws_cloudwatch_event_target" "toptask_survey_commit_schedule" {
  rule      = aws_cloudwatch_event_rule.toptask_survey_commit_schedule.name
  target_id = "toptask-survey-commit-lambda"
  arn       = aws_lambda_function.toptask_survey_commit.arn
}

resource "aws_lambda_permission" "toptask_survey_commit_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.toptask_survey_commit.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.toptask_survey_commit_schedule.arn
}

# Note: Lambda permissions and CloudWatch Log Groups are managed above for scheduled functions
# API Gateway Lambda permissions are managed by the CDS lambda module
