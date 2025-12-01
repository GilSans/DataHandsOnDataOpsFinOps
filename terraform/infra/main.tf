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



##############################################################################
########             INSTANCIAS EC2                              #############
##############################################################################
module "ec2_instance" {
  source              = "./modules/ec2"
  ami_id              = "ami-04b4f1a9cf54c11d0"
  instance_type       = "t3a.2xlarge"
  subnet_id           = module.vpc_public.public_subnet_ids[0]
  vpc_id              = module.vpc_public.vpc_id
  key_name            = "cjmm-datahandson-cb"
  associate_public_ip = true
  instance_name       = "data-handson-mds-ec2-${var.environment}"

  user_data = templatefile("${path.module}/scripts/bootstrap/ec2_bootstrap.sh", {})

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
    }
  ]
}


###############################################################################
#########            DMS SERVERLESS                             #############
###############################################################################
module "dms_serverless" {
  source = "./modules/dms-serverless"

  environment                 = var.environment
  vpc_id                      = module.vpc_public.vpc_id
  subnet_ids                  = module.vpc_public.private_subnet_ids
  replication_subnet_group_id = module.vpc_public.dms_subnet_group_id

  source_endpoint_config = {
    endpoint_id   = "postgres-source-${var.environment}"
    engine_name   = "postgres"
    server_name   = module.rds_postgres.db_instance_endpoint
    port          = module.rds_postgres.db_instance_port
    database_name = module.rds_postgres.db_name
    username      = "postgres"
    password      = var.rds_password
  }

  target_s3_config = {
    bucket_name   = var.s3_bucket_raw
    bucket_folder = "raw/postgres/"
  }

  table_mappings = jsonencode({
    "rules" = [
      {
        "rule-type" = "selection"
        "rule-id"   = "1"
        "rule-name" = "1"
        "object-locator" = {
          "schema-name" = "public"
          "table-name"  = "%"
        }
        "rule-action" = "include"
      }
    ]
  })
}

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
