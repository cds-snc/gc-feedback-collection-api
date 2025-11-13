terraform {
  source = "../../../aws//sns"
}

# SNS is created first with no dependencies
# SQS queues will be created next and subscribe to these topics
# All required variables (product_name, billing_code) come from common_variables.tf

include {
  path = find_in_parent_folders("root.hcl")
}
