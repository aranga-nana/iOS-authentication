variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "lambda_functions" {
  description = "Map of Lambda function ARNs"
  type        = map(string)
}

variable "enable_cors" {
  description = "Enable CORS for the API"
  type        = bool
  default     = true
}

variable "enable_compression" {
  description = "Enable response compression"
  type        = bool
  default     = true
}

variable "enable_caching" {
  description = "Enable API Gateway caching"
  type        = bool
  default     = false
}

variable "throttle_rate_limit" {
  description = "API Gateway throttle rate limit (requests per second)"
  type        = number
  default     = 1000
}

variable "throttle_burst_limit" {
  description = "API Gateway throttle burst limit"
  type        = number
  default     = 2000
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "domain_name" {
  description = "Custom domain name for the API"
  type        = string
  default     = null
}

variable "certificate_arn" {
  description = "ACM certificate ARN for custom domain"
  type        = string
  default     = null
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID for custom domain"
  type        = string
  default     = null
}

variable "allowed_source_ips" {
  description = "List of allowed source IP addresses"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
