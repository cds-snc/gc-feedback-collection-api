terraform {
  source = "../../../aws//hosted_zone"
}

include {
  path = find_in_parent_folders("root.hcl")
}

dependencies {
  paths = ["../api_gateway"]
}

dependency "api_gateway" {
  config_path                             = "../api_gateway"
  mock_outputs_allowed_terraform_commands = ["init", "fmt", "validate", "plan", "show"]
  mock_outputs_merge_with_state           = true
  mock_outputs = {
    api_gateway_id                   = ""
    api_gateway_stage_name           = ""
    certificate_arn                  = ""
    certificate_validation_options   = {}
  }
}

inputs = {
  # domain, billing_code, and region come from root.hcl
  api_gateway_id                  = dependency.api_gateway.outputs.api_gateway_id
  api_gateway_stage_name          = dependency.api_gateway.outputs.api_gateway_stage_name
  certificate_arn                 = dependency.api_gateway.outputs.certificate_arn
  api_cert_validation_options     = dependency.api_gateway.outputs.certificate_validation_options
}