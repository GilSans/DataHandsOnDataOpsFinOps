resource "aws_emrserverless_application" "spark_app" {
  name          = "${var.project_name}-spark-${var.environment}"
  release_label = var.release_label
  type          = "Spark"

  initial_capacity {
    initial_capacity_type = "Driver"
    initial_capacity_config {
      worker_count = 1
      worker_configuration {
        cpu    = var.driver_cpu
        memory = var.driver_memory
      }
    }
  }

  initial_capacity {
    initial_capacity_type = "Executor"
    initial_capacity_config {
      worker_count = var.executor_count
      worker_configuration {
        cpu    = var.executor_cpu
        memory = var.executor_memory
      }
    }
  }

  maximum_capacity {
    cpu    = var.max_cpu
    memory = var.max_memory
  }

  auto_start_configuration {
    enabled = true
  }

  auto_stop_configuration {
    enabled              = true
    idle_timeout_minutes = var.idle_timeout_minutes
  }

  tags = {
    Name        = "${var.project_name}-spark-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_iam_role" "emr_serverless_execution_role" {
  name = "${var.project_name}-emr-serverless-execution-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "emr-serverless.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "emr_serverless_s3_policy" {
  name = "${var.project_name}-emr-serverless-s3-${var.environment}"
  role = aws_iam_role.emr_serverless_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket}/*",
          "arn:aws:s3:::${var.s3_bucket}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:GetPartitions"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}
