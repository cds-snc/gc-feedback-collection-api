terraform {
  source = "../../../aws//api_gateway"
}

dependencies {
  paths = ["../lambda"]
}

dependency "lambda" {
  config_path                             = "../lambda"
  mock_outputs_allowed_terraform_commands = ["init", "fmt", "validate", "plan", "show"]
  mock_outputs_merge_with_state           = true
  mock_outputs = {
    lambda_queue_problem_form_invoke_arn        = "arn:aws:lambda:ca-central-1:123456789012:function:mock-queue-problem-form"
    lambda_queue_toptask_survey_form_invoke_arn = "arn:aws:lambda:ca-central-1:123456789012:function:mock-queue-toptask-survey-form"
    queue_problem_form_lambda_name              = "mock-queue-problem-form"
    queue_toptask_survey_form_lambda_name       = "mock-queue-toptask-survey-form"
  }
}

inputs = {
  queue_problem_form_lambda_invoke_arn        = dependency.lambda.outputs.lambda_queue_problem_form_invoke_arn
  queue_problem_form_lambda_name              = dependency.lambda.outputs.queue_problem_form_lambda_name
  queue_toptask_survey_form_lambda_invoke_arn = dependency.lambda.outputs.lambda_queue_toptask_survey_form_invoke_arn
  queue_toptask_survey_form_lambda_name       = dependency.lambda.outputs.queue_toptask_survey_form_lambda_name
}

include {
  path = find_in_parent_folders("root.hcl")
}
