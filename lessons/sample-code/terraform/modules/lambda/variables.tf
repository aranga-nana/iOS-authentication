variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "sam_stack_name" {
  description = "Name of the SAM CloudFormation stack"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "create_shared_layer" {
  description = "Whether to create a shared Lambda layer"
  type        = bool
  default     = false
}

variable "create_error_notifications" {
  description = "Whether to create SNS topic for error notifications"
  type        = bool
  default     = true
}

variable "alarm_sns_topic" {
  description = "SNS topic ARN for alarms"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
