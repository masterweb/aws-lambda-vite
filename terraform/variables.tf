variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-1"
}

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "jorge-2026"
}

variable "project_name" {
  description = "Prefix for resource names"
  type        = string
  default     = "todo"
}

variable "table_name" {
  description = "DynamoDB table name"
  type        = string
  default     = "todo-tasks"
}
