# API Gateway REST API for feedback collection

resource "aws_api_gateway_rest_api" "feedback_api" {
  name        = "${var.product_name}-rest-api"
  description = "REST API for feedback collection (forms)"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

# /problem resource
resource "aws_api_gateway_resource" "problem" {
  rest_api_id = aws_api_gateway_rest_api.feedback_api.id
  parent_id   = aws_api_gateway_rest_api.feedback_api.root_resource_id
  path_part   = "problem"
}

# /problem/email resource
resource "aws_api_gateway_resource" "problem_email" {
  rest_api_id = aws_api_gateway_rest_api.feedback_api.id
  parent_id   = aws_api_gateway_resource.problem.id
  path_part   = "email"
}

# /problem/form resource
resource "aws_api_gateway_resource" "problem_form" {
  rest_api_id = aws_api_gateway_rest_api.feedback_api.id
  parent_id   = aws_api_gateway_resource.problem.id
  path_part   = "form"
}

# /toptask resource
resource "aws_api_gateway_resource" "toptask" {
  rest_api_id = aws_api_gateway_rest_api.feedback_api.id
  parent_id   = aws_api_gateway_rest_api.feedback_api.root_resource_id
  path_part   = "toptask"
}

# /toptask/email resource
resource "aws_api_gateway_resource" "toptask_email" {
  rest_api_id = aws_api_gateway_rest_api.feedback_api.id
  parent_id   = aws_api_gateway_resource.toptask.id
  path_part   = "email"
}

# /toptask/survey resource
resource "aws_api_gateway_resource" "toptask_survey" {
  rest_api_id = aws_api_gateway_rest_api.feedback_api.id
  parent_id   = aws_api_gateway_resource.toptask.id
  path_part   = "survey"
}

# /toptask/survey/form resource
resource "aws_api_gateway_resource" "toptask_survey_form" {
  rest_api_id = aws_api_gateway_rest_api.feedback_api.id
  parent_id   = aws_api_gateway_resource.toptask_survey.id
  path_part   = "form"
}

# POST /problem/form method
resource "aws_api_gateway_method" "problem_form_post" {
  rest_api_id   = aws_api_gateway_rest_api.feedback_api.id
  resource_id   = aws_api_gateway_resource.problem_form.id
  http_method   = "POST"
  authorization = "NONE" # Can be changed to AWS_IAM or API_KEY for security
}

# POST /toptask/survey/form method
resource "aws_api_gateway_method" "toptask_survey_form_post" {
  rest_api_id   = aws_api_gateway_rest_api.feedback_api.id
  resource_id   = aws_api_gateway_resource.toptask_survey_form.id
  http_method   = "POST"
  authorization = "NONE" # Can be changed to AWS_IAM or API_KEY for security
}

# Lambda integrations
resource "aws_api_gateway_integration" "problem_form_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.feedback_api.id
  resource_id             = aws_api_gateway_resource.problem_form.id
  http_method             = aws_api_gateway_method.problem_form_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${var.queue_problem_form_lambda_invoke_arn}/invocations"
}

resource "aws_api_gateway_integration" "toptask_survey_form_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.feedback_api.id
  resource_id             = aws_api_gateway_resource.toptask_survey_form.id
  http_method             = aws_api_gateway_method.toptask_survey_form_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${var.queue_toptask_survey_form_lambda_invoke_arn}/invocations"
}

# CORS configuration for web forms
resource "aws_api_gateway_method" "problem_form_options" {
  rest_api_id   = aws_api_gateway_rest_api.feedback_api.id
  resource_id   = aws_api_gateway_resource.problem_form.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "problem_form_options" {
  rest_api_id = aws_api_gateway_rest_api.feedback_api.id
  resource_id = aws_api_gateway_resource.problem_form.id
  http_method = aws_api_gateway_method.problem_form_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "problem_form_options" {
  rest_api_id = aws_api_gateway_rest_api.feedback_api.id
  resource_id = aws_api_gateway_resource.problem_form.id
  http_method = aws_api_gateway_method.problem_form_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "problem_form_options" {
  rest_api_id = aws_api_gateway_rest_api.feedback_api.id
  resource_id = aws_api_gateway_resource.problem_form.id
  http_method = aws_api_gateway_method.problem_form_options.http_method
  status_code = aws_api_gateway_method_response.problem_form_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# CORS for toptask survey form
resource "aws_api_gateway_method" "toptask_survey_form_options" {
  rest_api_id   = aws_api_gateway_rest_api.feedback_api.id
  resource_id   = aws_api_gateway_resource.toptask_survey_form.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "toptask_survey_form_options" {
  rest_api_id = aws_api_gateway_rest_api.feedback_api.id
  resource_id = aws_api_gateway_resource.toptask_survey_form.id
  http_method = aws_api_gateway_method.toptask_survey_form_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "toptask_survey_form_options" {
  rest_api_id = aws_api_gateway_rest_api.feedback_api.id
  resource_id = aws_api_gateway_resource.toptask_survey_form.id
  http_method = aws_api_gateway_method.toptask_survey_form_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "toptask_survey_form_options" {
  rest_api_id = aws_api_gateway_rest_api.feedback_api.id
  resource_id = aws_api_gateway_resource.toptask_survey_form.id
  http_method = aws_api_gateway_method.toptask_survey_form_options.http_method
  status_code = aws_api_gateway_method_response.toptask_survey_form_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# API Gateway deployment
resource "aws_api_gateway_deployment" "feedback_api" {
  rest_api_id = aws_api_gateway_rest_api.feedback_api.id

  depends_on = [
    aws_api_gateway_integration.problem_form_lambda,
    aws_api_gateway_integration.toptask_survey_form_lambda,
    aws_api_gateway_integration.problem_form_options,
    aws_api_gateway_integration.toptask_survey_form_options
  ]

  lifecycle {
    create_before_destroy = true
  }

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.problem_form.id,
      aws_api_gateway_method.problem_form_post.id,
      aws_api_gateway_integration.problem_form_lambda.id,
      aws_api_gateway_resource.toptask_survey_form.id,
      aws_api_gateway_method.toptask_survey_form_post.id,
      aws_api_gateway_integration.toptask_survey_form_lambda.id,
    ]))
  }
}

# API Gateway stage
resource "aws_api_gateway_stage" "feedback_api" {
  deployment_id = aws_api_gateway_deployment.feedback_api.id
  rest_api_id   = aws_api_gateway_rest_api.feedback_api.id
  stage_name    = var.env

  xray_tracing_enabled = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

# CloudWatch log group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/${var.product_name}"
  retention_in_days = 30

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

# API Gateway account settings for CloudWatch Logs
resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn
}

# IAM role for API Gateway CloudWatch logging
resource "aws_iam_role" "api_gateway_cloudwatch" {
  name = "${var.product_name}-api-gateway-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    CostCentre = var.billing_code
    Terraform  = true
  }
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  role       = aws_iam_role.api_gateway_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}
