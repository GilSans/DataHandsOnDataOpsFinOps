output "emr_serverless_application_id" {
  value       = module.emr_serverless.application_id
  description = "EMR Serverless Application ID"
}

output "emr_serverless_execution_role_arn" {
  value       = module.emr_serverless.execution_role_arn
  description = "EMR Serverless Execution Role ARN"
}

output "aws_application_id" {
  value       = module.aws_application.application_id
  description = "AWS Application ID"
}

output "aws_application_arn" {
  value       = module.aws_application.application_arn
  description = "AWS Application ARN"
}
