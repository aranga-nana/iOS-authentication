# Outputs for iOS Authentication System
# Supporting infrastructure that complements SAM-deployed resources

# SAM Stack References
output "sam_stack_name" {
  description = "Name of the SAM CloudFormation stack"
  value       = var.sam_stack_name
}

output "sam_api_gateway_id" {
  description = "API Gateway ID from SAM stack"
  value       = local.api_gateway_id
}

output "sam_users_table_name" {
  description = "DynamoDB Users table name from SAM stack"
  value       = local.users_table_name
}

# CloudFront Distribution
output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.cloudfront.distribution_id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = module.cloudfront.domain_name
}

output "cloudfront_hosted_zone_id" {
  description = "CloudFront distribution hosted zone ID"
  value       = module.cloudfront.hosted_zone_id
}

# WAF
output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = module.waf.web_acl_arn
}

# Secrets Manager
output "firebase_credentials_secret_arn" {
  description = "ARN of Firebase credentials secret"
  value       = aws_secretsmanager_secret.firebase_credentials.arn
  sensitive   = true
}

output "jwt_secret_arn" {
  description = "ARN of JWT secret"
  value       = aws_secretsmanager_secret.jwt_secret.arn
  sensitive   = true
}

# CloudWatch Monitoring
output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = module.monitoring.dashboard_url
}
}

output "cloudwatch_log_groups" {
  description = "CloudWatch log group names"
  value       = module.monitoring.log_group_names
}

# Security Outputs
output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = module.security.waf_web_acl_arn
  sensitive   = true
}

# Secrets Manager Outputs
output "secrets_manager_arn" {
  description = "Secrets Manager secret ARN"
  value       = aws_secretsmanager_secret.app_secrets.arn
  sensitive   = true
}

# S3 Outputs
output "lambda_deployment_bucket" {
  description = "S3 bucket for Lambda deployments"
  value       = aws_s3_bucket.lambda_deployments.bucket
}

# CloudFront Outputs (Production only)
output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = var.environment == "prod" ? aws_cloudfront_distribution.api[0].id : null
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = var.environment == "prod" ? aws_cloudfront_distribution.api[0].domain_name : null
}

# Environment Information
output "environment" {
  description = "Deployment environment"
  value       = var.environment
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "project_name" {
  description = "Project name"
  value       = var.project_name
}

# Resource Tags
output "common_tags" {
  description = "Common tags applied to all resources"
  value       = local.common_tags
}

# Connection Information for iOS App
output "ios_app_config" {
  description = "Configuration values for iOS app"
  value = {
    api_base_url     = module.api_gateway.api_url
    aws_region      = var.aws_region
    environment     = var.environment
    api_stage       = module.api_gateway.stage_name
  }
}

# Development Tools
output "local_development_endpoints" {
  description = "Endpoints for local development"
  value = {
    api_gateway_url = module.api_gateway.api_url
    dynamodb_table  = module.dynamodb.table_names["users"]
    log_groups     = module.monitoring.log_group_names
  }
}

# Monitoring URLs
output "monitoring_urls" {
  description = "URLs for monitoring and observability"
  value = {
    cloudwatch_dashboard = module.monitoring.dashboard_url
    cloudwatch_logs     = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups"
    xray_console       = var.enable_xray_tracing ? "https://console.aws.amazon.com/xray/home?region=${var.aws_region}" : null
  }
}

# Security Information
output "security_info" {
  description = "Security configuration information"
  value = {
    waf_enabled        = var.enable_waf
    rate_limiting      = var.enable_rate_limiting
    geo_blocking       = var.enable_geo_blocking
    encryption_at_rest = true
    https_only        = true
  }
  sensitive = true
}

# Backup Information
output "backup_info" {
  description = "Backup configuration information"
  value = {
    point_in_time_recovery = var.enable_point_in_time_recovery
    automated_backups     = var.enable_automated_backups
    retention_days       = var.backup_retention_days
  }
}

# Cost Information
output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown"
  value = {
    environment = var.environment
    note       = "Actual costs may vary based on usage patterns"
    components = {
      lambda_functions = "Based on invocations and duration"
      api_gateway     = "Based on API calls"
      dynamodb       = var.dynamodb_billing_mode == "PAY_PER_REQUEST" ? "Pay per request" : "Provisioned capacity"
      cloudwatch     = "Based on log ingestion and retention"
      waf           = var.enable_waf ? "Enabled" : "Disabled"
    }
  }
}

# Deployment Information
output "deployment_info" {
  description = "Deployment metadata"
  value = {
    deployed_at    = timestamp()
    deployed_by    = "terraform"
    terraform_version = ">=1.0"
    aws_account_id = data.aws_caller_identity.current.account_id
  }
}
