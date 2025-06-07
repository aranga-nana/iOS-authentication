# Security Module Outputs

# WAF Outputs
output "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value       = aws_wafv2_web_acl.api_protection.arn
}

output "waf_web_acl_id" {
  description = "ID of the WAF Web ACL"
  value       = aws_wafv2_web_acl.api_protection.id
}

output "waf_web_acl_name" {
  description = "Name of the WAF Web ACL"
  value       = aws_wafv2_web_acl.api_protection.name
}

output "waf_log_group_arn" {
  description = "ARN of the WAF CloudWatch log group"
  value       = aws_cloudwatch_log_group.waf_logs.arn
}

output "waf_log_group_name" {
  description = "Name of the WAF CloudWatch log group"
  value       = aws_cloudwatch_log_group.waf_logs.name
}

# Secrets Manager Outputs
output "jwt_secret_arn" {
  description = "ARN of the JWT secret in Secrets Manager"
  value       = aws_secretsmanager_secret.jwt_secret.arn
}

output "jwt_secret_name" {
  description = "Name of the JWT secret in Secrets Manager"
  value       = aws_secretsmanager_secret.jwt_secret.name
}

output "firebase_credentials_arn" {
  description = "ARN of the Firebase credentials secret in Secrets Manager"
  value       = aws_secretsmanager_secret.firebase_credentials.arn
}

output "firebase_credentials_name" {
  description = "Name of the Firebase credentials secret in Secrets Manager"
  value       = aws_secretsmanager_secret.firebase_credentials.name
}

# KMS Outputs
output "kms_key_arn" {
  description = "ARN of the KMS key"
  value       = aws_kms_key.main.arn
}

output "kms_key_id" {
  description = "ID of the KMS key"
  value       = aws_kms_key.main.key_id
}

output "kms_alias_arn" {
  description = "ARN of the KMS key alias"
  value       = aws_kms_alias.main.arn
}

output "kms_alias_name" {
  description = "Name of the KMS key alias"
  value       = aws_kms_alias.main.name
}

# Security Group Outputs
output "lambda_security_group_id" {
  description = "ID of the Lambda security group (if VPC is used)"
  value       = var.vpc_id != null ? aws_security_group.lambda[0].id : null
}

output "lambda_security_group_arn" {
  description = "ARN of the Lambda security group (if VPC is used)"
  value       = var.vpc_id != null ? aws_security_group.lambda[0].arn : null
}

# CloudWatch Alarms Outputs
output "waf_blocked_requests_alarm_arn" {
  description = "ARN of the WAF blocked requests alarm"
  value       = aws_cloudwatch_metric_alarm.waf_blocked_requests.arn
}

output "waf_rate_limit_alarm_arn" {
  description = "ARN of the WAF rate limit alarm"
  value       = aws_cloudwatch_metric_alarm.waf_rate_limit_triggered.arn
}

# IAM Role Outputs
output "waf_logging_role_arn" {
  description = "ARN of the WAF logging IAM role"
  value       = aws_iam_role.waf_logging.arn
}

output "waf_logging_role_name" {
  description = "Name of the WAF logging IAM role"
  value       = aws_iam_role.waf_logging.name
}

# Configuration Outputs for Reference
output "security_configuration" {
  description = "Security configuration summary"
  value = {
    waf_enabled              = true
    rate_limiting_enabled    = var.waf_enable_rate_limiting
    sql_injection_protection = var.waf_enable_sql_injection_protection
    xss_protection          = var.waf_enable_xss_protection
    geo_blocking_enabled    = var.enable_geo_blocking
    kms_encryption_enabled  = true
    secrets_manager_enabled = true
    security_monitoring     = var.security_monitoring_enabled
    compliance_mode         = var.compliance_mode
    backup_enabled          = var.cross_region_backup
  }
}

# Security Policy Documents (for reference)
output "lambda_kms_policy" {
  description = "KMS policy for Lambda access"
  value = {
    version = "2012-10-17"
    statement = [
      {
        effect = "Allow"
        action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        resource = aws_kms_key.main.arn
      }
    ]
  }
}

output "secrets_manager_policy" {
  description = "Secrets Manager policy for Lambda access"
  value = {
    version = "2012-10-17"
    statement = [
      {
        effect = "Allow"
        action = [
          "secretsmanager:GetSecretValue"
        ]
        resource = [
          aws_secretsmanager_secret.jwt_secret.arn,
          aws_secretsmanager_secret.firebase_credentials.arn
        ]
      }
    ]
  }
}

# Security Endpoints for Applications
output "security_endpoints" {
  description = "Security-related endpoints and resources for application configuration"
  value = {
    kms_key_alias          = aws_kms_alias.main.name
    jwt_secret_name        = aws_secretsmanager_secret.jwt_secret.name
    firebase_secret_name   = aws_secretsmanager_secret.firebase_credentials.name
    waf_web_acl_name       = aws_wafv2_web_acl.api_protection.name
    security_log_group     = aws_cloudwatch_log_group.waf_logs.name
  }
}

# Compliance and Audit Information
output "compliance_info" {
  description = "Compliance and audit configuration details"
  value = {
    compliance_mode           = var.compliance_mode
    audit_logging_enabled     = var.audit_logging_enabled
    encryption_at_rest        = var.data_encryption_at_rest.enabled
    encryption_in_transit     = var.data_encryption_in_transit.enabled
    backup_retention_days     = var.backup_retention_days
    cross_region_backup       = var.cross_region_backup
    log_retention_days        = var.log_retention_days
    kms_key_rotation_enabled  = var.kms_key_rotation_enabled
  }
}

# Monitoring and Alerting Configuration
output "monitoring_config" {
  description = "Security monitoring and alerting configuration"
  value = {
    waf_monitoring_enabled     = var.enable_waf_logging
    security_alarms_enabled    = var.security_monitoring_enabled
    blocked_requests_threshold = aws_cloudwatch_metric_alarm.waf_blocked_requests.threshold
    rate_limit_threshold      = aws_cloudwatch_metric_alarm.waf_rate_limit_triggered.threshold
    alarm_sns_topic           = var.alarm_sns_topic
  }
}

# Regional Information
output "deployment_info" {
  description = "Deployment and regional information"
  value = {
    aws_region     = data.aws_region.current.name
    aws_account_id = data.aws_caller_identity.current.account_id
    project_name   = var.project_name
    environment    = var.environment
  }
}
