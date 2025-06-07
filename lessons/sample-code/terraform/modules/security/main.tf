# Security Module for iOS Authentication System

# WAF Web ACL for API Gateway
resource "aws_wafv2_web_acl" "api_protection" {
  name  = "${var.project_name}-${var.environment}-api-waf"
  scope = "REGIONAL"
  
  default_action {
    allow {}
  }
  
  # Rate limiting rule
  rule {
    name     = "RateLimitRule"
    priority = 1
    
    action {
      block {}
    }
    
    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
        
        scope_down_statement {
          geo_match_statement {
            country_codes = var.allowed_countries
          }
        }
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
      sampled_requests_enabled   = true
    }
  }
  
  # SQL injection protection
  rule {
    name     = "SQLInjectionRule"
    priority = 2
    
    action {
      block {}
    }
    
    statement {
      sqli_match_statement {
        field_to_match {
          body {}
        }
        text_transformation {
          priority = 1
          type     = "URL_DECODE"
        }
        text_transformation {
          priority = 2
          type     = "HTML_ENTITY_DECODE"
        }
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLInjectionRule"
      sampled_requests_enabled   = true
    }
  }
  
  # XSS protection
  rule {
    name     = "XSSRule"
    priority = 3
    
    action {
      block {}
    }
    
    statement {
      xss_match_statement {
        field_to_match {
          body {}
        }
        text_transformation {
          priority = 1
          type     = "URL_DECODE"
        }
        text_transformation {
          priority = 2
          type     = "HTML_ENTITY_DECODE"
        }
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "XSSRule"
      sampled_requests_enabled   = true
    }
  }
  
  # Known bad inputs rule
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 4
    
    override_action {
      none {}
    }
    
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }
  
  # Core rule set
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 5
    
    override_action {
      none {}
    }
    
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
        
        excluded_rule {
          name = "SizeRestrictions_BODY"
        }
        
        excluded_rule {
          name = "GenericRFI_BODY"
        }
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }
  
  # Geo-blocking rule (if specific countries are blocked)
  dynamic "rule" {
    for_each = length(var.blocked_countries) > 0 ? [1] : []
    content {
      name     = "GeoBlockRule"
      priority = 6
      
      action {
        block {}
      }
      
      statement {
        geo_match_statement {
          country_codes = var.blocked_countries
        }
      }
      
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "GeoBlockRule"
        sampled_requests_enabled   = true
      }
    }
  }
  
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-${var.environment}-waf"
    sampled_requests_enabled   = true
  }
  
  tags = var.tags
}

# Associate WAF with API Gateway
resource "aws_wafv2_web_acl_association" "api_gateway" {
  resource_arn = var.api_gateway_arn
  web_acl_arn  = aws_wafv2_web_acl.api_protection.arn
}

# CloudWatch Log Group for WAF
resource "aws_cloudwatch_log_group" "waf_logs" {
  name              = "/aws/wafv2/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  
  tags = var.tags
}

# WAF Logging Configuration
resource "aws_wafv2_web_acl_logging_configuration" "main" {
  resource_arn            = aws_wafv2_web_acl.api_protection.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf_logs.arn]
  
  redacted_field {
    single_header {
      name = "authorization"
    }
  }
  
  redacted_field {
    single_header {
      name = "cookie"
    }
  }
}

# Secrets Manager for JWT secret
resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "${var.project_name}/${var.environment}/jwt-secret"
  description             = "JWT secret for ${var.project_name} ${var.environment}"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0
  
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = jsonencode({
    jwt_secret = var.jwt_secret != null ? var.jwt_secret : random_password.jwt_secret[0].result
  })
}

# Generate random JWT secret if not provided
resource "random_password" "jwt_secret" {
  count = var.jwt_secret == null ? 1 : 0
  
  length  = 64
  special = true
}

# Secrets Manager for Firebase credentials
resource "aws_secretsmanager_secret" "firebase_credentials" {
  name                    = "${var.project_name}/${var.environment}/firebase-credentials"
  description             = "Firebase credentials for ${var.project_name} ${var.environment}"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0
  
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "firebase_credentials" {
  secret_id = aws_secretsmanager_secret.firebase_credentials.id
  secret_string = jsonencode({
    project_id    = var.firebase_project_id
    client_email  = var.firebase_client_email
    private_key   = var.firebase_private_key
  })
}

# KMS Key for encryption
resource "aws_kms_key" "main" {
  description             = "KMS key for ${var.project_name} ${var.environment}"
  deletion_window_in_days = var.environment == "prod" ? 30 : 7
  enable_key_rotation     = true
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Lambda access"
        Effect = "Allow"
        Principal = {
          AWS = var.lambda_execution_role_arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
  
  tags = var.tags
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.project_name}-${var.environment}"
  target_key_id = aws_kms_key.main.key_id
}

# Security Group for Lambda (if VPC is used)
resource "aws_security_group" "lambda" {
  count = var.vpc_id != null ? 1 : 0
  
  name_prefix = "${var.project_name}-${var.environment}-lambda-"
  vpc_id      = var.vpc_id
  description = "Security group for Lambda functions"
  
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound"
  }
  
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP outbound"
  }
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-lambda-sg"
  })
}

# IAM role for WAF logging
resource "aws_iam_role" "waf_logging" {
  name = "${var.project_name}-${var.environment}-waf-logging"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "wafv2.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.tags
}

resource "aws_iam_role_policy" "waf_logging" {
  name = "${var.project_name}-${var.environment}-waf-logging"
  role = aws_iam_role.waf_logging.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.waf_logs.arn}:*"
      }
    ]
  })
}

# CloudWatch Alarms for security events
resource "aws_cloudwatch_metric_alarm" "waf_blocked_requests" {
  alarm_name          = "${var.project_name}-${var.environment}-waf-blocked-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = "100"
  alarm_description   = "This metric monitors blocked requests by WAF"
  alarm_actions       = var.alarm_sns_topic != null ? [var.alarm_sns_topic] : []
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    WebACL = aws_wafv2_web_acl.api_protection.name
    Rule   = "ALL"
    Region = data.aws_region.current.name
  }
  
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "waf_rate_limit_triggered" {
  alarm_name          = "${var.project_name}-${var.environment}-waf-rate-limit"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = "50"
  alarm_description   = "This metric monitors rate limiting triggers"
  alarm_actions       = var.alarm_sns_topic != null ? [var.alarm_sns_topic] : []
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    WebACL = aws_wafv2_web_acl.api_protection.name
    Rule   = "RateLimitRule"
    Region = data.aws_region.current.name
  }
  
  tags = var.tags
}

# Resource-based policy for Secrets Manager
resource "aws_secretsmanager_resource_policy" "jwt_secret" {
  secret_arn = aws_secretsmanager_secret.jwt_secret.arn
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.lambda_execution_role_arn
        }
        Action   = "secretsmanager:GetSecretValue"
        Resource = "*"
        Condition = {
          StringEquals = {
            "secretsmanager:ResourceTag/Environment" = var.environment
          }
        }
      }
    ]
  })
}

resource "aws_secretsmanager_resource_policy" "firebase_credentials" {
  secret_arn = aws_secretsmanager_secret.firebase_credentials.arn
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.lambda_execution_role_arn
        }
        Action   = "secretsmanager:GetSecretValue"
        Resource = "*"
        Condition = {
          StringEquals = {
            "secretsmanager:ResourceTag/Environment" = var.environment
          }
        }
      }
    ]
  })
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
