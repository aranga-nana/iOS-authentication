# Monitoring Module for iOS Authentication System

# SNS Topic for alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"
  
  tags = var.tags
}

resource "aws_sns_topic_subscription" "email_alerts" {
  count = var.alarm_email != null ? 1 : 0
  
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-dashboard"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        
        properties = {
          metrics = [
            for func_name in var.lambda_function_names : [
              "AWS/Lambda", "Invocations", "FunctionName", func_name
            ]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "Lambda Invocations"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        
        properties = {
          metrics = [
            for func_name in var.lambda_function_names : [
              "AWS/Lambda", "Errors", "FunctionName", func_name
            ]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "Lambda Errors"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        
        properties = {
          metrics = [
            for func_name in var.lambda_function_names : [
              "AWS/Lambda", "Duration", "FunctionName", func_name
            ]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Lambda Duration"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", "${var.project_name}-${var.environment}-api"],
            [".", "4XXError", ".", "."],
            [".", "5XXError", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "API Gateway Metrics"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiName", "${var.project_name}-${var.environment}-api"],
            [".", "IntegrationLatency", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "API Gateway Latency"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        
        properties = {
          metrics = [
            for table_name in var.dynamodb_table_names : [
              "AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", table_name
            ]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "DynamoDB Read Capacity"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 18
        width  = 24
        height = 6
        
        properties = {
          query   = "SOURCE '/aws/lambda/${var.project_name}-${var.environment}-register-user' | fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 100"
          region  = data.aws_region.current.name
          title   = "Recent Lambda Errors"
        }
      }
    ]
  })
  
  depends_on = [aws_sns_topic.alerts]
}

# Custom CloudWatch Metrics for Application
resource "aws_cloudwatch_log_metric_filter" "error_count" {
  name           = "${var.project_name}-${var.environment}-error-count"
  log_group_name = "/aws/lambda/${var.project_name}-${var.environment}-register-user"
  pattern        = "ERROR"
  
  metric_transformation {
    name      = "ErrorCount"
    namespace = "${var.project_name}/${var.environment}"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "authentication_failures" {
  name           = "${var.project_name}-${var.environment}-auth-failures"
  log_group_name = "/aws/lambda/${var.project_name}-${var.environment}-login-user"
  pattern        = "INVALID_AUTH_TOKEN"
  
  metric_transformation {
    name      = "AuthenticationFailures"
    namespace = "${var.project_name}/${var.environment}"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "rate_limit_exceeded" {
  name           = "${var.project_name}-${var.environment}-rate-limit"
  log_group_name = "/aws/lambda/${var.project_name}-${var.environment}-register-user"
  pattern        = "RATE_LIMIT_EXCEEDED"
  
  metric_transformation {
    name      = "RateLimitExceeded"
    namespace = "${var.project_name}/${var.environment}"
    value     = "1"
  }
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "api_gateway_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-api-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors API Gateway 4XX errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    ApiName = "${var.project_name}-${var.environment}-api"
  }
  
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "api_gateway_server_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-api-server-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors API Gateway 5XX errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    ApiName = "${var.project_name}-${var.environment}-api"
  }
  
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "api_gateway_latency" {
  alarm_name          = "${var.project_name}-${var.environment}-api-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Average"
  threshold           = "5000"
  alarm_description   = "This metric monitors API Gateway latency"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    ApiName = "${var.project_name}-${var.environment}-api"
  }
  
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_read_throttles" {
  count = length(var.dynamodb_table_names)
  
  alarm_name          = "${var.project_name}-${var.environment}-dynamodb-read-throttles-${var.dynamodb_table_names[count.index]}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ReadThrottles"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors DynamoDB read throttles"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    TableName = var.dynamodb_table_names[count.index]
  }
  
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_write_throttles" {
  count = length(var.dynamodb_table_names)
  
  alarm_name          = "${var.project_name}-${var.environment}-dynamodb-write-throttles-${var.dynamodb_table_names[count.index]}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "WriteThrottles"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors DynamoDB write throttles"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    TableName = var.dynamodb_table_names[count.index]
  }
  
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "authentication_failures" {
  alarm_name          = "${var.project_name}-${var.environment}-auth-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "AuthenticationFailures"
  namespace           = "${var.project_name}/${var.environment}"
  period              = "300"
  statistic           = "Sum"
  threshold           = "20"
  alarm_description   = "This metric monitors authentication failures"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
  
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "rate_limit_exceeded" {
  alarm_name          = "${var.project_name}-${var.environment}-rate-limit-exceeded"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "RateLimitExceeded"
  namespace           = "${var.project_name}/${var.environment}"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors rate limit violations"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
  
  tags = var.tags
}

# CloudWatch Insights queries
resource "aws_cloudwatch_query_definition" "error_analysis" {
  name = "${var.project_name}-${var.environment}-error-analysis"
  
  log_group_names = [
    for func_name in var.lambda_function_names : 
    "/aws/lambda/${func_name}"
  ]
  
  query_string = <<EOF
fields @timestamp, @message, @requestId
| filter @message like /ERROR/
| stats count(*) by bin(5m)
| sort @timestamp desc
EOF
}

resource "aws_cloudwatch_query_definition" "performance_analysis" {
  name = "${var.project_name}-${var.environment}-performance-analysis"
  
  log_group_names = [
    for func_name in var.lambda_function_names : 
    "/aws/lambda/${func_name}"
  ]
  
  query_string = <<EOF
fields @timestamp, @duration, @billedDuration, @memorySize, @maxMemoryUsed
| filter @type = "REPORT"
| stats avg(@duration), max(@duration), min(@duration) by bin(5m)
| sort @timestamp desc
EOF
}

resource "aws_cloudwatch_query_definition" "security_events" {
  name = "${var.project_name}-${var.environment}-security-events"
  
  log_group_names = [
    for func_name in var.lambda_function_names : 
    "/aws/lambda/${func_name}"
  ]
  
  query_string = <<EOF
fields @timestamp, @message, @requestId
| filter @message like /INVALID_AUTH_TOKEN/ or @message like /ACCESS_DENIED/ or @message like /RATE_LIMIT_EXCEEDED/
| stats count(*) by bin(1h)
| sort @timestamp desc
EOF
}

# X-Ray tracing (if enabled)
resource "aws_xray_sampling_rule" "main" {
  count = var.enable_xray_tracing ? 1 : 0
  
  rule_name      = "${var.project_name}-${var.environment}-sampling"
  priority       = 9000
  version        = 1
  reservoir_size = 1
  fixed_rate     = 0.1
  url_path       = "*"
  host           = "*"
  http_method    = "*"
  service_type   = "*"
  service_name   = "*"
  resource_arn   = "*"
  
  tags = var.tags
}

# EventBridge rules for monitoring
resource "aws_cloudwatch_event_rule" "lambda_state_change" {
  name        = "${var.project_name}-${var.environment}-lambda-state-change"
  description = "Capture Lambda function state changes"
  
  event_pattern = jsonencode({
    source      = ["aws.lambda"]
    detail-type = ["Lambda Function Invocation Result - Failure"]
    detail = {
      functionName = var.lambda_function_names
    }
  })
  
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.lambda_state_change.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.alerts.arn
}

resource "aws_sns_topic_policy" "alerts" {
  arn = aws_sns_topic.alerts.arn
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
