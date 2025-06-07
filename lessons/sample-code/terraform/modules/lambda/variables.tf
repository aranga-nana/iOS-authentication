variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "function_names" {
  description = "Map of function handler names to display names"
  type        = map(string)
  default = {
    registerUser       = "register-user"
    loginUser         = "login-user"
    getUserProfile    = "get-user-profile"
    updateUserProfile = "update-user-profile"
    deleteUserAccount = "delete-user-account"
  }
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "nodejs18.x"
}

variable "timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 512
}

variable "reserved_concurrency" {
  description = "Reserved concurrency for each function"
  type        = map(number)
  default = {
    registerUser       = 20
    loginUser         = 50
    getUserProfile    = 100
    updateUserProfile = 20
    deleteUserAccount = 5
  }
}

variable "environment_variables" {
  description = "Environment variables for Lambda functions"
  type        = map(string)
  default     = {}
}

variable "dynamodb_table_arns" {
  description = "List of DynamoDB table ARNs"
  type        = list(string)
  default     = []
}

variable "vpc_config" {
  description = "VPC configuration for Lambda functions"
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "enable_xray_tracing" {
  description = "Enable X-Ray tracing"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "alarm_sns_topic" {
  description = "SNS topic ARN for alarms"
  type        = string
  default     = null
}

variable "create_shared_layer" {
  description = "Create a shared Lambda layer for dependencies"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
