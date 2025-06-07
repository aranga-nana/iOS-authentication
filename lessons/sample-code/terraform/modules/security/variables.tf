# Security Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "api_gateway_arn" {
  description = "ARN of the API Gateway to protect with WAF"
  type        = string
}

variable "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role for KMS and Secrets Manager access"
  type        = string
}

variable "waf_rate_limit" {
  description = "Rate limit for WAF (requests per 5 minutes)"
  type        = number
  default     = 2000
}

variable "allowed_countries" {
  description = "List of allowed country codes for geo-matching (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = ["US", "CA", "GB", "AU", "DE", "FR", "JP", "IN"]
}

variable "blocked_countries" {
  description = "List of blocked country codes (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "jwt_secret" {
  description = "JWT secret key (if not provided, will be generated randomly)"
  type        = string
  default     = null
  sensitive   = true
}

variable "firebase_project_id" {
  description = "Firebase project ID"
  type        = string
}

variable "firebase_client_email" {
  description = "Firebase service account client email"
  type        = string
}

variable "firebase_private_key" {
  description = "Firebase service account private key"
  type        = string
  sensitive   = true
}

variable "vpc_id" {
  description = "VPC ID for Lambda security group (optional)"
  type        = string
  default     = null
}

variable "alarm_sns_topic" {
  description = "SNS topic ARN for security alarms"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Validation rules
variable "waf_enable_sql_injection_protection" {
  description = "Enable SQL injection protection in WAF"
  type        = bool
  default     = true
}

variable "waf_enable_xss_protection" {
  description = "Enable XSS protection in WAF"
  type        = bool
  default     = true
}

variable "waf_enable_rate_limiting" {
  description = "Enable rate limiting in WAF"
  type        = bool
  default     = true
}

variable "secrets_rotation_enabled" {
  description = "Enable automatic rotation for secrets"
  type        = bool
  default     = false
}

variable "kms_key_rotation_enabled" {
  description = "Enable automatic rotation for KMS keys"
  type        = bool
  default     = true
}

variable "enable_waf_logging" {
  description = "Enable WAF request logging"
  type        = bool
  default     = true
}

variable "security_monitoring_enabled" {
  description = "Enable security monitoring and alerting"
  type        = bool
  default     = true
}

# Advanced security configurations
variable "waf_custom_rules" {
  description = "Custom WAF rules configuration"
  type = list(object({
    name     = string
    priority = number
    action   = string
    statement = object({
      type = string
      config = map(any)
    })
  }))
  default = []
}

variable "ip_whitelist" {
  description = "List of IP addresses/CIDR blocks to whitelist"
  type        = list(string)
  default     = []
}

variable "ip_blacklist" {
  description = "List of IP addresses/CIDR blocks to blacklist"
  type        = list(string)
  default     = []
}

variable "enable_geo_blocking" {
  description = "Enable geographic blocking based on country codes"
  type        = bool
  default     = false
}

variable "security_headers" {
  description = "Security headers to enforce via WAF"
  type = object({
    enforce_https = bool
    hsts_enabled  = bool
    csp_enabled   = bool
  })
  default = {
    enforce_https = true
    hsts_enabled  = true
    csp_enabled   = true
  }
}

# Compliance and audit settings
variable "compliance_mode" {
  description = "Compliance mode (PCI, HIPAA, SOX, etc.)"
  type        = string
  default     = "standard"
  
  validation {
    condition = contains([
      "standard",
      "pci",
      "hipaa",
      "sox",
      "gdpr"
    ], var.compliance_mode)
    error_message = "Compliance mode must be one of: standard, pci, hipaa, sox, gdpr."
  }
}

variable "audit_logging_enabled" {
  description = "Enable comprehensive audit logging"
  type        = bool
  default     = true
}

variable "data_encryption_at_rest" {
  description = "Encryption configuration for data at rest"
  type = object({
    enabled        = bool
    kms_key_id     = string
    algorithm      = string
  })
  default = {
    enabled        = true
    kms_key_id     = ""
    algorithm      = "AES256"
  }
}

variable "data_encryption_in_transit" {
  description = "Encryption configuration for data in transit"
  type = object({
    enabled       = bool
    tls_version   = string
    cipher_suites = list(string)
  })
  default = {
    enabled       = true
    tls_version   = "1.2"
    cipher_suites = ["TLS_AES_128_GCM_SHA256", "TLS_AES_256_GCM_SHA384"]
  }
}

# Backup and disaster recovery
variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30
}

variable "cross_region_backup" {
  description = "Enable cross-region backup for disaster recovery"
  type        = bool
  default     = false
}

variable "backup_regions" {
  description = "List of regions for cross-region backups"
  type        = list(string)
  default     = []
}
