# API Gateway Module for iOS Authentication System
# NOTE: Core API Gateway resources are now managed by AWS SAM
# This module provides additional configurations and integrations

# Data source to reference SAM-deployed API Gateway
data "aws_api_gateway_rest_api" "sam_api" {
  name = var.sam_api_name
}

# Custom domain name for API Gateway (if needed)
resource "aws_api_gateway_domain_name" "custom_domain" {
  count = var.custom_domain_name != null ? 1 : 0
  
  domain_name              = var.custom_domain_name
  regional_certificate_arn = var.certificate_arn
  
  endpoint_configuration {
    types = ["REGIONAL"]
  }
  
  tags = var.tags
}

# Base path mapping for custom domain
resource "aws_api_gateway_base_path_mapping" "custom_domain" {
  count = var.custom_domain_name != null ? 1 : 0
  
  api_id      = data.aws_api_gateway_rest_api.sam_api.id
  stage_name  = var.stage_name
  domain_name = aws_api_gateway_domain_name.custom_domain[0].domain_name
}
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "main" {
  depends_on = [
    aws_api_gateway_method.auth_options,
    aws_api_gateway_method.register_post,
    aws_api_gateway_method.login_post,
    aws_api_gateway_method.users_get,
    aws_api_gateway_method.users_put,
    aws_api_gateway_method.users_delete,
    aws_api_gateway_integration.auth_options,
    aws_api_gateway_integration.register_post,
    aws_api_gateway_integration.login_post,
    aws_api_gateway_integration.users_get,
    aws_api_gateway_integration.users_put,
    aws_api_gateway_integration.users_delete
  ]
  
  rest_api_id = aws_api_gateway_rest_api.main.id
  
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.auth.id,
      aws_api_gateway_resource.register.id,
      aws_api_gateway_resource.login.id,
      aws_api_gateway_resource.users.id,
      aws_api_gateway_resource.user_id.id,
      aws_api_gateway_method.auth_options.id,
      aws_api_gateway_method.register_post.id,
      aws_api_gateway_method.login_post.id,
      aws_api_gateway_method.users_get.id,
      aws_api_gateway_method.users_put.id,
      aws_api_gateway_method.users_delete.id,
      aws_api_gateway_integration.auth_options.id,
      aws_api_gateway_integration.register_post.id,
      aws_api_gateway_integration.login_post.id,
      aws_api_gateway_integration.users_get.id,
      aws_api_gateway_integration.users_put.id,
      aws_api_gateway_integration.users_delete.id,
    ]))
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.environment
  
  # Enable caching
  cache_cluster_enabled = var.enable_caching
  cache_cluster_size   = var.enable_caching ? "0.5" : null
  
  # Throttling settings
  throttle_settings {
    rate_limit  = var.throttle_rate_limit
    burst_limit = var.throttle_burst_limit
  }
  
  # Method settings
  method_settings {
    method_path = "*/*"
    
    # Logging
    logging_level      = "INFO"
    data_trace_enabled = true
    metrics_enabled    = true
    
    # Caching
    caching_enabled      = var.enable_caching
    cache_ttl_in_seconds = var.enable_caching ? 300 : null
    cache_key_parameters = []
    
    # Throttling per method
    throttling_rate_limit  = var.throttle_rate_limit
    throttling_burst_limit = var.throttle_burst_limit
  }
  
  # Access logging
  access_log_destination_arn = aws_cloudwatch_log_group.api_gateway.arn
  access_log_format = jsonencode({
    requestId      = "$context.requestId"
    extendedRequestId = "$context.extendedRequestId"
    ip            = "$context.identity.sourceIp"
    caller        = "$context.identity.caller"
    user          = "$context.identity.user"
    requestTime   = "$context.requestTime"
    httpMethod    = "$context.httpMethod"
    resourcePath  = "$context.resourcePath"
    status        = "$context.status"
    protocol      = "$context.protocol"
    responseLength = "$context.responseLength"
    responseTime  = "$context.responseTime"
    requestLength = "$context.requestLength"
    error         = "$context.error.message"
    errorType     = "$context.error.messageString"
  })
  
  tags = var.tags
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/api-gateway/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  
  tags = var.tags
}

# Resources
resource "aws_api_gateway_resource" "auth" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "auth"
}

resource "aws_api_gateway_resource" "register" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.auth.id
  path_part   = "register"
}

resource "aws_api_gateway_resource" "login" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.auth.id
  path_part   = "login"
}

resource "aws_api_gateway_resource" "users" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "users"
}

resource "aws_api_gateway_resource" "user_id" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.users.id
  path_part   = "{userId}"
}

# CORS Configuration
resource "aws_api_gateway_method" "auth_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.auth.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "auth_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.auth.id
  http_method = aws_api_gateway_method.auth_options.http_method
  
  type = "MOCK"
  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_method_response" "auth_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.auth.id
  http_method = aws_api_gateway_method.auth_options.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "auth_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.auth.id
  http_method = aws_api_gateway_method.auth_options.http_method
  status_code = aws_api_gateway_method_response.auth_options.status_code
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,HEAD,OPTIONS,POST,PUT,DELETE'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# Register endpoint
resource "aws_api_gateway_method" "register_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.register.id
  http_method   = "POST"
  authorization = "NONE"
  
  request_validator_id = aws_api_gateway_request_validator.body_validator.id
  
  request_models = {
    "application/json" = aws_api_gateway_model.register_request.name
  }
}

resource "aws_api_gateway_integration" "register_post" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.register.id
  http_method = aws_api_gateway_method.register_post.http_method
  
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_functions["registerUser"]
  
  timeout_milliseconds = 29000
}

# Login endpoint
resource "aws_api_gateway_method" "login_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.login.id
  http_method   = "POST"
  authorization = "NONE"
  
  request_validator_id = aws_api_gateway_request_validator.body_validator.id
  
  request_models = {
    "application/json" = aws_api_gateway_model.login_request.name
  }
}

resource "aws_api_gateway_integration" "login_post" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.login.id
  http_method = aws_api_gateway_method.login_post.http_method
  
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_functions["loginUser"]
  
  timeout_milliseconds = 29000
}

# User profile endpoints
resource "aws_api_gateway_method" "users_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.user_id.id
  http_method   = "GET"
  authorization = "NONE"
  
  request_parameters = {
    "method.request.path.userId"      = true
    "method.request.header.Authorization" = true
  }
}

resource "aws_api_gateway_integration" "users_get" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.user_id.id
  http_method = aws_api_gateway_method.users_get.http_method
  
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_functions["getUserProfile"]
  
  timeout_milliseconds = 29000
}

resource "aws_api_gateway_method" "users_put" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.user_id.id
  http_method   = "PUT"
  authorization = "NONE"
  
  request_parameters = {
    "method.request.path.userId"      = true
    "method.request.header.Authorization" = true
  }
  
  request_validator_id = aws_api_gateway_request_validator.body_validator.id
  
  request_models = {
    "application/json" = aws_api_gateway_model.update_user_request.name
  }
}

resource "aws_api_gateway_integration" "users_put" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.user_id.id
  http_method = aws_api_gateway_method.users_put.http_method
  
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_functions["updateUserProfile"]
  
  timeout_milliseconds = 29000
}

resource "aws_api_gateway_method" "users_delete" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.user_id.id
  http_method   = "DELETE"
  authorization = "NONE"
  
  request_parameters = {
    "method.request.path.userId"      = true
    "method.request.header.Authorization" = true
  }
}

resource "aws_api_gateway_integration" "users_delete" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.user_id.id
  http_method = aws_api_gateway_method.users_delete.http_method
  
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_functions["deleteUserAccount"]
  
  timeout_milliseconds = 29000
}

# Request Validators
resource "aws_api_gateway_request_validator" "body_validator" {
  name                        = "${var.project_name}-${var.environment}-body-validator"
  rest_api_id                 = aws_api_gateway_rest_api.main.id
  validate_request_body       = true
  validate_request_parameters = true
}

# Request Models
resource "aws_api_gateway_model" "register_request" {
  rest_api_id  = aws_api_gateway_rest_api.main.id
  name         = "RegisterRequest"
  content_type = "application/json"
  
  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title     = "Register Request Schema"
    type      = "object"
    required  = ["idToken"]
    properties = {
      idToken = {
        type = "string"
        minLength = 1
      }
      userData = {
        type = "object"
        properties = {
          displayName = {
            type = "string"
            maxLength = 100
          }
          profilePicture = {
            type = "string"
            format = "uri"
          }
          preferences = {
            type = "object"
          }
        }
      }
    }
  })
}

resource "aws_api_gateway_model" "login_request" {
  rest_api_id  = aws_api_gateway_rest_api.main.id
  name         = "LoginRequest"
  content_type = "application/json"
  
  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title     = "Login Request Schema"
    type      = "object"
    required  = ["idToken"]
    properties = {
      idToken = {
        type = "string"
        minLength = 1
      }
    }
  })
}

resource "aws_api_gateway_model" "update_user_request" {
  rest_api_id  = aws_api_gateway_rest_api.main.id
  name         = "UpdateUserRequest"
  content_type = "application/json"
  
  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title     = "Update User Request Schema"
    type      = "object"
    properties = {
      displayName = {
        type = "string"
        maxLength = 100
      }
      profilePicture = {
        type = "string"
        format = "uri"
      }
      preferences = {
        type = "object"
      }
    }
  })
}

# Lambda permissions
resource "aws_lambda_permission" "api_gateway_register" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = split(":", var.lambda_functions["registerUser"])[6]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gateway_login" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = split(":", var.lambda_functions["loginUser"])[6]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gateway_get_profile" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = split(":", var.lambda_functions["getUserProfile"])[6]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gateway_update_profile" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = split(":", var.lambda_functions["updateUserProfile"])[6]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gateway_delete_account" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = split(":", var.lambda_functions["deleteUserAccount"])[6]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# Custom Domain (optional)
resource "aws_api_gateway_domain_name" "main" {
  count = var.domain_name != null ? 1 : 0
  
  domain_name              = var.domain_name
  regional_certificate_arn = var.certificate_arn
  
  endpoint_configuration {
    types = ["REGIONAL"]
  }
  
  tags = var.tags
}

resource "aws_api_gateway_base_path_mapping" "main" {
  count = var.domain_name != null ? 1 : 0
  
  api_id      = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  domain_name = aws_api_gateway_domain_name.main[0].domain_name
}

# Route53 record for custom domain
resource "aws_route53_record" "api" {
  count = var.domain_name != null && var.hosted_zone_id != null ? 1 : 0
  
  name    = aws_api_gateway_domain_name.main[0].domain_name
  type    = "A"
  zone_id = var.hosted_zone_id
  
  alias {
    evaluate_target_health = true
    name                   = aws_api_gateway_domain_name.main[0].regional_domain_name
    zone_id                = aws_api_gateway_domain_name.main[0].regional_zone_id
  }
}
