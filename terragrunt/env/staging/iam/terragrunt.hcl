terraform {
  source = "../../../aws//iam"
}

dependencies {
  paths = ["../sqs"]
}

dependency "sqs" {
  config_path                             = "../sqs"
  mock_outputs_allowed_terraform_commands = ["init", "fmt", "validate", "plan", "show"]
  mock_outputs_merge_with_state           = true
  mock_outputs = {
    problem_queue_arn = ""
    toptask_queue_arn = ""
  }
}

inputs = {
  problem_queue_arn                  = dependency.sqs.outputs.problem_queue_arn
  toptask_queue_arn                  = dependency.sqs.outputs.toptask_queue_arn
  dto_feedback_cj_docdb_username_arn = "arn:aws:ssm:ca-central-1:992382783569:parameter/dto-feedback-cj/documentdb/username"
  dto_feedback_cj_docdb_password_arn = "arn:aws:ssm:ca-central-1:992382783569:parameter/dto-feedback-cj/documentdb/password"
}

include {
  path = find_in_parent_folders("root.hcl")
}
