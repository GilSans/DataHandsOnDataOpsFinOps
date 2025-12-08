output "emr_serverless_application_id" {
  value       = module.emr_serverless.application_id
  description = "EMR Serverless Application ID"
}

output "emr_serverless_execution_role_arn" {
  value       = module.emr_serverless.execution_role_arn
  description = "EMR Serverless Execution Role ARN"
}
