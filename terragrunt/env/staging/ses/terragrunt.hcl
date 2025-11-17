terraform {
  source = "../../../aws//ses"
}

dependencies {
  paths = ["../sns"]
}

dependency "sns" {
  config_path                             = "../sns"
  mock_outputs_allowed_terraform_commands = ["init", "fmt", "validate", "plan", "show"]
  mock_outputs_merge_with_state           = true
  mock_outputs = {
    problem_topic_arn = ""
    toptask_topic_arn = ""
  }
}

inputs = {
  account_id            = local.vars.inputs.account_id
  problem_sns_topic_arn = dependency.sns.outputs.problem_topic_arn
  toptask_sns_topic_arn = dependency.sns.outputs.toptask_topic_arn
  ses_domain            = local.vars.inputs.domain
}

include {
  path = find_in_parent_folders("root.hcl")
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env_vars.hcl"))
}
