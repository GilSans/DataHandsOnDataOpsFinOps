data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

###############################################################################
#########             VPC E SUBNETS                               #############
###############################################################################
module "vpc_public" {
  source               = "./modules/vpc"
  project_name         = "data-handson-mds"
  vpc_name             = "data-handson-mds-vpc-${var.environment}"
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
  availability_zones   = ["us-east-2a", "us-east-2b"]
}

###############################################################################
#########             RDS POSTGRESQL                              #############
###############################################################################
module "rds_postgres" {
  source = "./modules/rds"

  environment       = var.environment
  vpc_id            = module.vpc_public.vpc_id
  public_subnet_ids = module.vpc_public.public_subnet_ids

  db_name     = "postgres"
  db_username = "postgres"
  db_password = var.rds_password

  instance_class    = "db.t3.large"
  allocated_storage = 50
}

###############################################################################
#########             REDSHIFT                                    #############
###############################################################################
module "redshift" {
  source = "./modules/redshift"

  cluster_identifier  = "data-handson-mds"
  database_name       = "datahandsonmds"
  master_username     = "admin"
  node_type           = "ra3.large"
  cluster_type        = "single-node"
  number_of_nodes     = 1
  publicly_accessible = true
  subnet_ids          = module.vpc_public.public_subnet_ids
  vpc_id              = module.vpc_public.vpc_id
  allowed_ips         = ["0.0.0.0/0"]
}



##############################################################################
########             INSTANCIAS EC2                              #############
##############################################################################
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

module "ec2_instance" {
  source              = "./modules/ec2"
  ami_id              = data.aws_ami.ubuntu.id
  instance_type       = "t3a.2xlarge"
  subnet_id           = module.vpc_public.public_subnet_ids[0]
  vpc_id              = module.vpc_public.vpc_id
  key_name            = "cjmm-mds-dq"
  associate_public_ip = true
  instance_name       = "data-handson-mds-ec2-${var.environment}"

  user_data = templatefile("${path.module}/scripts/bootstrap/ec2_bootstrap.sh", {
    AWS_ACCOUNT_ID = data.aws_caller_identity.current.account_id
  })

  ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      from_port   = 3000
      to_port     = 3000
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}


###############################################################################
#########            DMS SERVERLESS                             #############
###############################################################################
# module "dms_serverless" {
#   source = "./modules/dms-serverless"

#   environment                 = var.environment
#   vpc_id                      = module.vpc_public.vpc_id
#   subnet_ids                  = module.vpc_public.private_subnet_ids
#   replication_subnet_group_id = module.vpc_public.dms_subnet_group_id

#   source_endpoint_config = {
#     endpoint_id   = "postgres-source-${var.environment}"
#     engine_name   = "postgres"
#     server_name   = module.rds_postgres.db_instance_endpoint
#     port          = module.rds_postgres.db_instance_port
#     database_name = module.rds_postgres.db_name
#     username      = "postgres"
#     password      = var.rds_password
#   }

#   target_s3_config = {
#     bucket_name   = var.s3_bucket_raw
#     bucket_folder = "raw/postgres/"
#   }

#   table_mappings = jsonencode({
#     "rules" = [
#       {
#         "rule-type" = "selection"
#         "rule-id"   = "1"
#         "rule-name" = "1"
#         "object-locator" = {
#           "schema-name" = "public"
#           "table-name"  = "%"
#         }
#         "rule-action" = "include"
#       }
#     ]
#   })
# }

###############################################################################
#########            GLUE JOBS                                   #############
###############################################################################
module "glue_jobs_dataopsfinops_s3tables" {
  source = "./modules/glue-job"

  project_name       = "data-handson-dataopsfinops-s3-tables"
  environment        = var.environment
  region             = var.region
  s3_bucket_scripts  = var.s3_bucket_scripts
  s3_bucket_data     = var.s3_bucket_raw
  scripts_local_path = "scripts/glue_etl/glue_etl_s3tables"

  job_scripts = {
    "datahandson-dataopsfinops-amazonsales-dw-table-stg-s3tables"           = "datahandson-dataopsfinops-amazonsales-dw-table-stg-s3tables.py",
    "datahandson-dataopsfinops-amazonsales-dw-dim-product-s3tables"         = "datahandson-dataopsfinops-amazonsales-dw-dim-product-s3tables.py",
    "datahandson-dataopsfinops-amazonsales-dw-dim-rating-s3tables"          = "datahandson-dataopsfinops-amazonsales-dw-dim-rating-s3tables.py",
    "datahandson-dataopsfinops-amazonsales-dw-dim-user-s3tables"            = "datahandson-dataopsfinops-amazonsales-dw-dim-user-s3tables.py",
    "datahandson-dataopsfinops-amazonsales-dw-dims-s3tables-gdq"            = "datahandson-dataopsfinops-amazonsales-dw-dims-s3tables-gdq.py",
    "datahandson-dataopsfinops-amazonsales-dw-fact-product-rating-s3tables" = "datahandson-dataopsfinops-amazonsales-dw-fact-product-rating-s3tables.py",
    "datahandson-dataopsfinops-amazonsales-dw-fact-sales-category-s3tables" = "datahandson-dataopsfinops-amazonsales-dw-fact-sales-category-s3tables.py",
    "datahandson-dataopsfinops-amazonsales-dw-facts-s3tables-gdq"           = "datahandson-dataopsfinops-amazonsales-dw-facts-s3tables-gdq.py",
  }

  worker_type       = "G.1X"
  number_of_workers = 3
  timeout           = 60
  max_retries       = 0

  extra_jars = "s3://cjmm-mds-lake-configs/jars/s3-tables-catalog-for-iceberg-0.1.7.jar"


  additional_arguments = {
    "--enable-glue-datacatalog" = "true"
    "--user-jars-first"         = "true"
    "--datalake-formats"        = "iceberg"
  }
}



###############################################################################
#########               STEP FUNCTIONS                            #############
###############################################################################
module "step_functions" {
  source = "./modules/step-functions"

  project_name = "datahandson-dataopsfinops"
  environment  = var.environment
  region       = var.region

  # Definições das máquinas de estado
  state_machines = {
    "datahandson-dataopsfinops-amazonsales-s3tables" = {
      definition_file = "sfn_definition_s3tables_amazonsales.json"
      type            = "STANDARD"
    }
    "airflow-health-check" = {
      definition_file = "sfn_definition_airflow_health_check.json"
      type            = "STANDARD"
    }
  }

  # Permissões adicionais para o Step Functions
  additional_iam_statements = [
    {
      Effect = "Allow"
      Action = [
        "glue:StartJobRun",
        "glue:GetJobRun",
        "glue:GetJobRuns",
        "glue:BatchStopJobRun"
      ]
      Resource = "*"
    },
    {
      Effect = "Allow"
      Action = [
        "lambda:InvokeFunction"
      ]
      Resource = "arn:aws:lambda:us-east-2:296735965303:function:airflow-health-check-lambda"
    },
    {
      Effect = "Allow"
      Action = [
        "sns:Publish"
      ]
      Resource = module.sns_data_quality_alerts.sns_topic_arn
    }
  ]

  # Anexar políticas gerenciadas
  attach_glue_policy = true

  # Configurações de logging
  log_retention_days     = 30
  include_execution_data = true
  logging_level          = "ALL"
}

###############################################################################
#########            METABASE DOCKER-COMPOSE UPLOAD               #############
###############################################################################
resource "aws_s3_object" "metabase_docker_compose" {
  bucket = var.s3_bucket_scripts
  key    = "metabase/docker-compose.yml"
  source = "../../metabase/docker-compose.yml"
  etag   = filemd5("../../metabase/docker-compose.yml")
}

###############################################################################
#########            AIRFLOW INFRA FILES UPLOAD                  #############
###############################################################################
locals {
  airflow_infra_files = fileset("../../airflow/infra", "**/*")
  bootstrap_files     = fileset("scripts/bootstrap", "**/*")
  emr_scripts         = fileset("../../airflow/dags/scripts", "**/*")
}

resource "aws_s3_object" "airflow_infra_files" {
  for_each = { for file in local.airflow_infra_files : file => file if !endswith(file, "/") }

  bucket = var.s3_bucket_scripts
  key    = "airflow/infra/${each.value}"
  source = "../../airflow/infra/${each.value}"
  etag   = filemd5("../../airflow/infra/${each.value}")
}

resource "aws_s3_object" "bootstrap_files" {
  for_each = { for file in local.bootstrap_files : file => file if !endswith(file, "/") }

  bucket = var.s3_bucket_scripts
  key    = "scripts/bootstrap/${each.value}"
  source = "scripts/bootstrap/${each.value}"
  etag   = filemd5("scripts/bootstrap/${each.value}")
}


###############################################################################
#########            LAMBDA FUNCTION WITH DOCKER                  #############
###############################################################################
module "lambda_function_duckdb" {
  source = "./modules/lambda_ecr"

  function_name = "datahandson-dataopsfinops-s3tables-duckdb"
  description   = "Python Lambda function for querying S3 tables with DuckDB"

  # Docker image URI (replace with your actual ECR URI after running build_and_push.sh)
  image_uri = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/lambda-duckdb:latest"

  # Optional parameters
  timeout                = 900
  memory_size            = 2048
  ephemeral_storage_size = 2048

  # Function URL configuration
  create_function_url    = true
  function_url_auth_type = "AWS_IAM" # Use AWS IAM for authentication

  environment_variables = {
    ENV_VAR_1 = "value1"
  }
}


###############################################################################
#########            SNS TOPICS                                  #############
###############################################################################
module "sns_data_quality_alerts" {
  source = "./modules/sns"

  project_name = "data-handson-dq"
  environment  = var.environment
  topic_name   = "data-handson-dq-alerts"
  display_name = "Data Quality Alerts"

  # Allow all accounts in your organization to publish to this topic
  publisher_principals = ["*"]
}


##############################################################################
#########            LAMBDA FUNCTIONS                            #############
###############################################################################
module "lambda_alert_dataquality" {
  source = "./modules/lambda"

  project_name     = "data-handson-dq"
  environment      = var.environment
  function_name    = "alert-dataquality-sqs-discord"
  description      = "Lambda function to send data quality alerts from SNS to Discord"
  handler          = "alert-dataquality-sqs-discord.lambda_handler"
  runtime          = "python3.9"
  timeout          = 60
  memory_size      = 128
  source_code_file = "alert-dataquality-sqs-discord.py"

  environment_variables = {
    DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1354503644946628769/bjvMnt1ZpcsMTt67nAe_vFwK6A1yVq6p0sUNRxNJNK1TJz8Gd4WgSxCAQHRToCf1itIj"
  }
}

# SNS subscription for alert Lambda
resource "aws_sns_topic_subscription" "lambda_alert_subscription" {
  topic_arn = module.sns_data_quality_alerts.sns_topic_arn
  protocol  = "lambda"
  endpoint  = module.lambda_alert_dataquality.lambda_function_arn
}

# Permission for SNS to invoke alert Lambda
resource "aws_lambda_permission" "sns_invoke_alert" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_alert_dataquality.lambda_function_name
  principal     = "sns.amazonaws.com"
  source_arn    = module.sns_data_quality_alerts.sns_topic_arn
}

module "lambda_glue_dq_error_handler" {
  source = "./modules/lambda"

  project_name     = "data-handson-dq"
  environment      = var.environment
  function_name    = "glue-dq-error-handler"
  description      = "Lambda function to handle Glue Data Quality error events"
  handler          = "glue-dq-error-handler.lambda_handler"
  runtime          = "python3.9"
  timeout          = 900
  memory_size      = 128
  source_code_file = "glue-dq-error-handler.py"

  environment_variables = {
    SNS_TOPIC_ARN = module.sns_data_quality_alerts.sns_topic_arn
  }

  # Add permissions to publish to SNS
  additional_policy_arns = ["arn:aws:iam::aws:policy/AmazonSNSFullAccess"]
}

###############################################################################
#########            EVENTBRIDGE RULES                           #############
###############################################################################
module "eventbridge_glue_dq_errors" {
  source = "./modules/eventbridge"

  project_name = "data-handson-dq"
  environment  = var.environment
  rule_name    = "glue-dq-errors"
  description  = "Capture Glue Data Quality error events"

  event_pattern = jsonencode({
    source      = ["aws.glue-dataquality"]
    detail-type = ["Data Quality Evaluation Results Available"]
    detail = {
      state = ["FAILED"]
    }
  })

  target_lambda_arn  = module.lambda_glue_dq_error_handler.lambda_function_arn
  target_lambda_name = module.lambda_glue_dq_error_handler.lambda_function_name
}

resource "aws_cloudwatch_event_rule" "ec2_state_change" {
  name        = "ec2-stopped-terminated-${var.environment}"
  description = "Capture EC2 instance state changes (stopped/terminated)"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
    detail = {
      state = ["stopped", "terminated"]
    }
  })
}

resource "aws_cloudwatch_event_target" "sns_ec2_alerts" {
  rule      = aws_cloudwatch_event_rule.ec2_state_change.name
  target_id = "SendToSNS"
  arn       = module.sns_data_quality_alerts.sns_topic_arn

  input_transformer {
    input_paths = {
      instance_id = "$.detail.instance-id"
      state       = "$.detail.state"
      region      = "$.region"
      time        = "$.time"
    }
    input_template = "\"EC2 Instance Alert: Instance <instance_id> in region <region> has changed to state <state> at <time>\""
  }
}

resource "aws_sns_topic_policy" "ec2_alerts_policy" {
  arn = module.sns_data_quality_alerts.sns_topic_arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = module.sns_data_quality_alerts.sns_topic_arn
      }
    ]
  })
}

###############################################################################
#########            AIRFLOW HEALTH CHECK                        #############
###############################################################################
module "lambda_airflow_health_check" {
  source = "./modules/lambda"

  project_name     = "data-handson-dq"
  environment      = var.environment
  function_name    = "airflow-health-check-lambda"
  description      = "Lambda function to check Airflow health status"
  handler          = "airflow-health-check-lambda.lambda_handler"
  runtime          = "python3.9"
  timeout          = 30
  memory_size      = 128
  source_code_file = "airflow-health-check-lambda.py"

  environment_variables = {
    AIRFLOW_HOST = "ec2-13-58-137-11.us-east-2.compute.amazonaws.com"
    AIRFLOW_PORT = "8080"
  }
}

###############################################################################
#########            EMR SERVERLESS                              #############
###############################################################################
module "emr_serverless" {
  source = "./modules/emr-serverless"

  project_name = "data-handson-mds"
  environment  = var.environment
  s3_bucket    = var.s3_bucket_raw

  release_label = "emr-7.0.0"

  driver_cpu    = "2 vCPU"
  driver_memory = "4 GB"

  executor_count  = 2
  executor_cpu    = "4 vCPU"
  executor_memory = "8 GB"

  max_cpu    = "20 vCPU"
  max_memory = "40 GB"

  idle_timeout_minutes = 5
}

resource "aws_s3_object" "emr_scripts" {
  for_each = { for file in local.emr_scripts : file => file if !endswith(file, "/") }

  bucket = var.s3_bucket_scripts
  key    = "scripts/emr/${each.value}"
  source = "../../airflow/dags/scripts/${each.value}"
  etag   = filemd5("../../airflow/dags/scripts/${each.value}")
}

###############################################################################
#########            AWS APPLICATION                             #############
###############################################################################
module "aws_application" {
  source = "./modules/aws-application"

  application_name = "data-handson-dataops-finops"
  description      = "DataOps and FinOps Training Application - Data Lake Architecture"
  environment      = var.environment
  project_name     = "data-handson-mds"
  owner            = "DataOps Team"
  cost_center      = "DataEngineering"
}
