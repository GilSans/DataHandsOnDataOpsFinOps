locals {
  common_tags = {
    "aws:servicecatalog:applicationName" = var.application_name
    "Environment"                        = var.environment
    "Project"                            = var.project_name
    "Owner"                              = var.owner
    "CostCenter"                         = var.cost_center
    "Terraform"                          = "true"
  }
}

output "common_tags" {
  value       = local.common_tags
  description = "Common tags to apply to all resources"
}
