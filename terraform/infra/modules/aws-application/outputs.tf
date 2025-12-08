output "application_id" {
  value       = aws_servicecatalogappregistry_application.main.id
  description = "Application ID"
}

output "application_arn" {
  value       = aws_servicecatalogappregistry_application.main.arn
  description = "Application ARN"
}

output "application_name" {
  value       = aws_servicecatalogappregistry_application.main.name
  description = "Application name"
}

output "application_tags" {
  value       = aws_servicecatalogappregistry_application.main.tags
  description = "Application tags for resource tagging"
}
