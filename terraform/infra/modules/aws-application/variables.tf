variable "application_name" {
  type        = string
  description = "Name of the application"
}

variable "description" {
  type        = string
  description = "Description of the application"
}

variable "environment" {
  type        = string
  description = "Environment (dev, staging, prod)"
}

variable "project_name" {
  type        = string
  description = "Project name"
}

variable "owner" {
  type        = string
  description = "Application owner"
  default     = "DataOps Team"
}

variable "cost_center" {
  type        = string
  description = "Cost center for billing"
  default     = "DataEngineering"
}
