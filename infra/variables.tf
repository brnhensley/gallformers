variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name used for resource naming"
  type        = string
  default     = "gallformers"
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
  default     = "885187511538"
}
