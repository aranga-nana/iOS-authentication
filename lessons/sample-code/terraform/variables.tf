# Variables for iOS Authentication System Terraform Configuration

# Project Configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "ios-auth"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "ios-auth-team"
}

# AWS Configuration
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

# Firebase Configuration
variable "firebase_project_id" {
  description = "Firebase project ID"
  type        = string
  sensitive   = true
}

variable "firebase_client_email" {
  description = "Firebase service account client email"
  type        = string
  sensitive   = true
}

variable "firebase_private_key" {
  description = "Firebase service account private key"
  type        = string
  sensitive   = true
}

# JWT Configuration
variable "jwt_expires_in" {
  description = "JWT token expiration time"
  type        = string
  default     = "24h"
}

# API Gateway Configuration
variable "api_throttle_rate_limit" {
  description = "API Gateway throttle rate limit (requests per second)"
  type        = number
  default     = 100
}

variable "api_throttle_burst_limit" {
  description = "API Gateway throttle burst limit"
  type        = number
  default     = 200
}

variable "api_domain_name" {
  description = "Custom domain name for API (optional)"
  type        = string
  default     = null
}

variable "api_certificate_arn" {
  description = "ACM certificate ARN for custom domain"
  type        = string
  default     = null
}

variable "api_hosted_zone_id" {
  description = "Route53 hosted zone ID for custom domain"
  type        = string
  default     = null
}

# Monitoring Configuration
variable "alarm_email" {
  description = "Email address for CloudWatch alarms"
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 30
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention period."
  }
}

variable "log_level" {
  description = "Application log level"
  type        = string
  default     = "info"
  validation {
    condition     = contains(["error", "warn", "info", "debug"], var.log_level)
    error_message = "Log level must be one of: error, warn, info, debug."
  }
}

# Security Configuration
variable "enable_waf" {
  description = "Enable AWS WAF for API protection"
  type        = bool
  default     = true
}

variable "enable_rate_limiting" {
  description = "Enable WAF rate limiting"
  type        = bool
  default     = true
}

variable "waf_rate_limit_requests" {
  description = "WAF rate limit requests per 5 minutes"
  type        = number
  default     = 2000
}

variable "enable_geo_blocking" {
  description = "Enable geographic blocking in WAF"
  type        = bool
  default     = false
}

variable "blocked_countries" {
  description = "List of country codes to block (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = []
}

# DynamoDB Configuration
variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode"
  type        = string
  default     = "PAY_PER_REQUEST"
  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.dynamodb_billing_mode)
    error_message = "DynamoDB billing mode must be either PAY_PER_REQUEST or PROVISIONED."
  }
}

variable "dynamodb_read_capacity" {
  description = "DynamoDB read capacity units (only for PROVISIONED billing)"
  type        = number
  default     = 5
}

variable "dynamodb_write_capacity" {
  description = "DynamoDB write capacity units (only for PROVISIONED billing)"
  type        = number
  default     = 5
}

variable "enable_point_in_time_recovery" {
  description = "Enable DynamoDB point-in-time recovery"
  type        = bool
  default     = true
}

variable "enable_deletion_protection" {
  description = "Enable DynamoDB deletion protection"
  type        = bool
  default     = false
}

# Lambda Configuration
variable "lambda_runtime" {
  description = "Lambda runtime version"
  type        = string
  default     = "nodejs18.x"
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
  validation {
    condition     = var.lambda_timeout >= 1 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 1 and 900 seconds."
  }
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 512
  validation {
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 10240
    error_message = "Lambda memory size must be between 128 and 10240 MB."
  }
}

variable "lambda_reserved_concurrency" {
  description = "Lambda reserved concurrency limit"
  type        = number
  default     = 10
}

# Environment-specific defaults
locals {
  environment_defaults = {
    dev = {
      lambda_memory_size         = 256
      lambda_reserved_concurrency = 5
      log_retention_days        = 7
      enable_waf               = false
      enable_deletion_protection = false
    }
    staging = {
      lambda_memory_size         = 512
      lambda_reserved_concurrency = 10
      log_retention_days        = 14
      enable_waf               = true
      enable_deletion_protection = false
    }
    prod = {
      lambda_memory_size         = 1024
      lambda_reserved_concurrency = 50
      log_retention_days        = 90
      enable_waf               = true
      enable_deletion_protection = true
    }
  }
}

# Backup Configuration
variable "enable_automated_backups" {
  description = "Enable automated backups for DynamoDB"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

# Multi-region Configuration
variable "enable_multi_region" {
  description = "Enable multi-region deployment"
  type        = bool
  default     = false
}

variable "backup_region" {
  description = "Backup AWS region for multi-region setup"
  type        = string
  default     = "us-west-2"
}

# Cost Optimization
variable "enable_cost_optimization" {
  description = "Enable cost optimization features"
  type        = bool
  default     = true
}

variable "lambda_provisioned_concurrency" {
  description = "Lambda provisioned concurrency (0 to disable)"
  type        = number
  default     = 0
}

# Development Features
variable "enable_xray_tracing" {
  description = "Enable AWS X-Ray tracing"
  type        = bool
  default     = false
}

variable "enable_enhanced_monitoring" {
  description = "Enable enhanced monitoring features"
  type        = bool
  default     = false
}
