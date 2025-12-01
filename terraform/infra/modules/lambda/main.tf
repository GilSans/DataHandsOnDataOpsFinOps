resource "aws_lambda_function" "this" {
  function_name = "${var.project_name}-${var.function_name}"
  description   = var.description
  handler       = var.handler
  runtime       = var.runtime
  timeout       = var.timeout
  memory_size   = var.memory_size

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  role = aws_iam_role.lambda_role.arn

  environment {
    variables = var.environment_variables
  }
}

# Create a zip file from the Lambda source code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../../scripts/lambda_code/${var.source_code_file}"
  output_path = "${path.module}/../../scripts/lambda_code/${var.function_name}.zip"
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.function_name}-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

}

# Basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Additional policy attachments if specified
resource "aws_iam_role_policy_attachment" "additional_policies" {
  for_each   = toset(var.additional_policy_arns)
  role       = aws_iam_role.lambda_role.name
  policy_arn = each.value
}

# Custom IAM policy for Lambda if specified
resource "aws_iam_policy" "lambda_custom_policy" {
  count       = length(var.custom_policy_json) > 0 ? 1 : 0
  name        = "${var.function_name}-custom-policy-${var.environment}"
  description = "Custom policy for ${var.function_name} Lambda function"
  policy      = var.custom_policy_json
}

resource "aws_iam_role_policy_attachment" "lambda_custom_policy" {
  count      = length(var.custom_policy_json) > 0 ? 1 : 0
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_custom_policy[0].arn
}
