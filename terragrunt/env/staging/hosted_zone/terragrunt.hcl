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
    api_gateway_domain_name        = ""
    api_gateway_hosted_zone_id     = ""
    certificate_validation_options = {}
  }
}

inputs = {
  api_gateway_domain_name     = dependency.api_gateway.outputs.api_gateway_domain_name
  api_gateway_hosted_zone_id  = dependency.api_gateway.outputs.api_gateway_hosted_zone_id
  api_cert_validation_options = dependency.api_gateway.outputs.certificate_validation_options
}