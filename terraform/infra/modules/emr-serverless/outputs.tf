output "application_id" {
  value = aws_emrserverless_application.spark_app.id
}

output "application_arn" {
  value = aws_emrserverless_application.spark_app.arn
}

output "execution_role_arn" {
  value = aws_iam_role.emr_serverless_execution_role.arn
}

output "execution_role_name" {
  value = aws_iam_role.emr_serverless_execution_role.name
}
