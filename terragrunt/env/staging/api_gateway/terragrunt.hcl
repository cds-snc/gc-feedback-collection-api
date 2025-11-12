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
    queue_problem_form_lambda_arn        = "arn:aws:lambda:ca-central-1:123456789012:function:mock-queue-problem-form"
    queue_toptask_survey_form_lambda_arn = "arn:aws:lambda:ca-central-1:123456789012:function:mock-queue-toptask-survey-form"
  }
}

inputs = {
  queue_problem_form_lambda_invoke_arn        = dependency.lambda.outputs.queue_problem_form_lambda_arn
  queue_toptask_survey_form_lambda_invoke_arn = dependency.lambda.outputs.queue_toptask_survey_form_lambda_arn
}

include {
  path = find_in_parent_folders("root.hcl")
}
