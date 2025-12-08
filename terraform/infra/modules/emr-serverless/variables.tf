variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "release_label" {
  type    = string
  default = "emr-7.0.0"
}

variable "s3_bucket" {
  type = string
}

variable "s3_bucket_logs" {
  type = string
}

variable "driver_cpu" {
  type    = string
  default = "2 vCPU"
}

variable "driver_memory" {
  type    = string
  default = "4 GB"
}

variable "executor_count" {
  type    = number
  default = 2
}

variable "executor_cpu" {
  type    = string
  default = "4 vCPU"
}

variable "executor_memory" {
  type    = string
  default = "8 GB"
}

variable "max_cpu" {
  type    = string
  default = "20 vCPU"
}

variable "max_memory" {
  type    = string
  default = "40 GB"
}

variable "idle_timeout_minutes" {
  type    = number
  default = 15
}
