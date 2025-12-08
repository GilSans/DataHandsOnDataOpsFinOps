resource "aws_servicecatalogappregistry_application" "main" {
  name        = var.application_name
  description = var.description

  tags = {
    "Application" = var.application_name
    "Environment" = var.environment
    "Project"     = var.project_name
    "Owner"       = var.owner
    "CostCenter"  = var.cost_center
    "Terraform"   = "true"
  }
}

resource "aws_servicecatalogappregistry_attribute_group" "main" {
  name        = "${var.application_name}-attributes"
  description = "Attribute group for ${var.application_name}"

  attributes = jsonencode({
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
    CostCenter  = var.cost_center
    Terraform   = "true"
  })

  tags = {
    "Application" = var.application_name
  }
}

resource "aws_servicecatalogappregistry_attribute_group_association" "main" {
  application_id     = aws_servicecatalogappregistry_application.main.id
  attribute_group_id = aws_servicecatalogappregistry_attribute_group.main.id
}
