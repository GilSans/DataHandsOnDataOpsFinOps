terraform {
  backend "s3" {
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
  default_tags {
    tags = {
      "Application" = "data-handson-dataops-finops"
      "Project"     = "data-handson-mds"
      "Environment" = var.environment
      "Owner"       = "DataOps Team"
      "CostCenter"  = "DataEngineering"
      "ManagedBy"   = "Terraform"
    }
  }
}
