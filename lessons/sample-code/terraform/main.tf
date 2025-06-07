# Terraform Configuration for iOS Authentication System
# Supporting infrastructure that complements the SAM-deployed Lambda functions

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }
  
  # Configure remote state storage
  backend "s3" {
    # Bucket and key will be configured via backend config file
    encrypt = true
  }
}

# Configure AWS Provider
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner
    }
  }
}

# Data sources for AWS account info
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Data source to reference SAM stack outputs
data "aws_cloudformation_stack" "sam_stack" {
  name = var.sam_stack_name
}

# Local values for resource naming
locals {
  common_name = "${var.project_name}-${var.environment}"
  
  # SAM stack outputs
  api_gateway_id = data.aws_cloudformation_stack.sam_stack.outputs["AuthApiId"]
  users_table_name = data.aws_cloudformation_stack.sam_stack.outputs["UsersTableName"]
  users_table_arn = data.aws_cloudformation_stack.sam_stack.outputs["UsersTableArn"]
  
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.owner
    SAMIntegration = "true"
  }
}

# Secrets Manager for Firebase credentials
resource "aws_secretsmanager_secret" "firebase_credentials" {
  name        = "${local.common_name}-firebase-credentials"
  description = "Firebase service account credentials for iOS authentication"
  
  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "firebase_credentials" {
  secret_id = aws_secretsmanager_secret.firebase_credentials.id
  secret_string = jsonencode({
    project_id   = var.firebase_project_id
    client_email = var.firebase_client_email
    private_key  = var.firebase_private_key
  })
}

# JWT Secret in Secrets Manager
resource "aws_secretsmanager_secret" "jwt_secret" {
  name        = "${local.common_name}-jwt-secret"
  description = "JWT secret key for token signing"
  
  tags = local.common_tags
}

resource "random_password" "jwt_secret" {
  length  = 64
  special = true
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = random_password.jwt_secret.result
}

# WAF for API Protection
module "waf" {
  source = "./modules/security"
  
  project_name     = var.project_name
  environment      = var.environment
  api_gateway_arn  = "arn:aws:apigateway:${data.aws_region.current.name}::/restapis/${local.api_gateway_id}/stages/*"
  
  tags = local.common_tags
}

# CloudFront Distribution for API
module "cloudfront" {
  source = "./modules/cloudfront"
  
  project_name       = var.project_name
  environment        = var.environment
  api_gateway_id     = local.api_gateway_id
  api_gateway_domain = "${local.api_gateway_id}.execute-api.${data.aws_region.current.name}.amazonaws.com"
  
  tags = local.common_tags
}

# Enhanced CloudWatch Monitoring
module "monitoring" {
  source = "./modules/monitoring"
  
  project_name     = var.project_name
  environment      = var.environment
  api_gateway_id   = local.api_gateway_id
  users_table_name = local.users_table_name
  
  # SNS topic for alerts
  alert_email = var.alert_email
  
  tags = local.common_tags
}
  memory_size = 512
  
  # Environment variables
  environment_variables = {
    STAGE                  = var.environment
    USERS_TABLE           = module.dynamodb.table_names["users"]
    JWT_SECRET            = random_password.jwt_secret.result
    JWT_EXPIRES_IN        = var.jwt_expires_in
    FIREBASE_PROJECT_ID   = var.firebase_project_id
    FIREBASE_CLIENT_EMAIL = var.firebase_client_email
    FIREBASE_PRIVATE_KEY  = var.firebase_private_key
    LOG_LEVEL            = var.log_level
  }
  
  # IAM permissions
  dynamodb_table_arns = [module.dynamodb.table_arns["users"]]
  
  tags = local.common_tags
}

# API Gateway
module "api_gateway" {
  source = "./modules/api-gateway"
  
  project_name = var.project_name
  environment  = var.environment
  
  # Lambda function ARNs
  lambda_functions = module.lambda.function_arns
  
  # API configuration
  enable_cors        = true
  enable_compression = true
  
  # Throttling
  throttle_rate_limit  = var.api_throttle_rate_limit
  throttle_burst_limit = var.api_throttle_burst_limit
  
  # Custom domain (optional)
  domain_name        = var.api_domain_name
  certificate_arn    = var.api_certificate_arn
  hosted_zone_id     = var.api_hosted_zone_id
  
  tags = local.common_tags
}

# CloudWatch Monitoring
module "monitoring" {
  source = "./modules/monitoring"
  
  project_name = var.project_name
  environment  = var.environment
  
  # Resources to monitor
  api_gateway_id      = module.api_gateway.api_id
  lambda_function_names = module.lambda.function_names
  dynamodb_table_names = [module.dynamodb.table_names["users"]]
  
  # Alerting
  alarm_email = var.alarm_email
  
  # Log retention
  log_retention_days = var.log_retention_days
  
  tags = local.common_tags
}

# Security Resources
module "security" {
  source = "./modules/security"
  
  project_name = var.project_name
  environment  = var.environment
  
  # API Gateway for WAF association
  api_gateway_arn = module.api_gateway.api_arn
  
  # Security configuration
  enable_waf              = var.enable_waf
  enable_rate_limiting    = var.enable_rate_limiting
  rate_limit_requests     = var.waf_rate_limit_requests
  enable_geo_blocking     = var.enable_geo_blocking
  blocked_countries       = var.blocked_countries
  
  tags = local.common_tags
}

# Secrets Manager for sensitive configuration
resource "aws_secretsmanager_secret" "app_secrets" {
  name        = "${local.common_name}-secrets"
  description = "Sensitive configuration for ${var.project_name} ${var.environment}"
  
  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = aws_secretsmanager_secret.app_secrets.id
  
  secret_string = jsonencode({
    jwt_secret            = random_password.jwt_secret.result
    firebase_project_id   = var.firebase_project_id
    firebase_client_email = var.firebase_client_email
    firebase_private_key  = var.firebase_private_key
  })
  
  lifecycle {
    ignore_changes = [secret_string]
  }
}

# CloudFront Distribution (for production)
resource "aws_cloudfront_distribution" "api" {
  count = var.environment == "prod" ? 1 : 0
  
  origin {
    domain_name = module.api_gateway.api_domain_name
    origin_id   = "api-gateway"
    
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  
  enabled = true
  
  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "api-gateway"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
    
    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Content-Type"]
      
      cookies {
        forward = "none"
      }
    }
    
    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }
  
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  
  viewer_certificate {
    cloudfront_default_certificate = true
  }
  
  tags = local.common_tags
}

# S3 Bucket for Lambda deployment packages
resource "aws_s3_bucket" "lambda_deployments" {
  bucket = "${local.common_name}-lambda-deployments"
  
  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "lambda_deployments" {
  bucket = aws_s3_bucket.lambda_deployments.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lambda_deployments" {
  bucket = aws_s3_bucket.lambda_deployments.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "lambda_deployments" {
  bucket = aws_s3_bucket.lambda_deployments.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
