terraform {
  source = "../../../aws//lambda"
}

dependencies {
  paths = ["../sqs", "../sns", "../iam"]
}

dependency "sqs" {
  config_path                             = "../sqs"
  mock_outputs_allowed_terraform_commands = ["init", "fmt", "validate", "plan", "show"]
  mock_outputs_merge_with_state           = true
  mock_outputs = {
    problem_queue_url = "https://sqs.ca-central-1.amazonaws.com/123456789012/mock-problem-queue"
    problem_queue_arn = "arn:aws:sqs:ca-central-1:123456789012:mock-problem-queue"
    toptask_queue_url = "https://sqs.ca-central-1.amazonaws.com/123456789012/mock-toptask-queue"
    toptask_queue_arn = "arn:aws:sqs:ca-central-1:123456789012:mock-toptask-queue"
  }
}

dependency "sns" {
  config_path                             = "../sns"
  mock_outputs_allowed_terraform_commands = ["init", "fmt", "validate", "plan", "show"]
  mock_outputs_merge_with_state           = true
  mock_outputs = {
    problem_topic_arn = "arn:aws:sns:ca-central-1:123456789012:mock-problem-topic"
    toptask_topic_arn = "arn:aws:sns:ca-central-1:123456789012:mock-toptask-topic"
  }
}

dependency "iam" {
  config_path                             = "../iam"
  mock_outputs_allowed_terraform_commands = ["init", "fmt", "validate", "plan", "show"]
  mock_outputs_merge_with_state           = true
  mock_outputs = {
    lambda_sqs_policy_arn         = "arn:aws:iam::123456789012:policy/mock-lambda-sqs-policy"
    lambda_sqs_receive_policy_arn = "arn:aws:iam::123456789012:policy/mock-lambda-sqs-receive-policy"
    lambda_ssm_policy_arn         = "arn:aws:iam::123456789012:policy/mock-lambda-ssm-policy"
  }
}

inputs = {
  problem_queue_url = dependency.sqs.outputs.problem_queue_url
  problem_queue_arn = dependency.sqs.outputs.problem_queue_arn
  toptask_queue_url = dependency.sqs.outputs.toptask_queue_url
  toptask_queue_arn = dependency.sqs.outputs.toptask_queue_arn

  problem_topic_arn = dependency.sns.outputs.problem_topic_arn
  toptask_topic_arn = dependency.sns.outputs.toptask_topic_arn

  lambda_sqs_policy_arn         = dependency.iam.outputs.lambda_sqs_policy_arn
  lambda_sqs_receive_policy_arn = dependency.iam.outputs.lambda_sqs_receive_policy_arn
  lambda_ssm_policy_arn         = dependency.iam.outputs.lambda_ssm_policy_arn

  api_gateway_execution_arn = "" # Will be set via mock until API Gateway is deployed

  # Lambda source code path
  lambda_source_code_path = "${get_repo_root()}/src"

  # Reference dto-feedback-cj shared infrastructure
  dto_feedback_cj_vpc_id                 = local.vars.inputs.dto_feedback_cj_vpc_id
  dto_feedback_cj_vpc_private_subnet_ids = local.vars.inputs.dto_feedback_cj_vpc_private_subnet_ids
  dto_feedback_cj_vpc_cidr_block         = local.vars.inputs.dto_feedback_cj_vpc_cidr_block
  dto_feedback_cj_docdb_endpoint         = local.vars.inputs.dto_feedback_cj_docdb_endpoint
  dto_feedback_cj_docdb_username_arn     = local.vars.inputs.dto_feedback_cj_docdb_username_arn
  dto_feedback_cj_docdb_password_arn     = local.vars.inputs.dto_feedback_cj_docdb_password_arn
}

include {
  path = find_in_parent_folders("root.hcl")
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env_vars.hcl"))
}
