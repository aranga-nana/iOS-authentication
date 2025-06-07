# Lambda Functions Module for iOS Authentication System
# This module now works with SAM-deployed Lambda functions

# Note: Core Lambda functions, API Gateway, and DynamoDB are now managed by SAM
# This module provides additional integrations and monitoring for the SAM stack

# Data source to get SAM stack outputs
data "aws_cloudformation_stack" "sam_stack" {
  name = var.sam_stack_name
}

# Additional Lambda Layer for shared utilities (if needed)
resource "aws_lambda_layer_version" "shared_utils" {
  count = var.create_shared_layer ? 1 : 0
  
  filename   = "${path.module}/../../layers/shared-utils.zip"
  layer_name = "${var.project_name}-${var.environment}-shared-utils"
  
  compatible_runtimes = ["nodejs18.x"]
  description        = "Shared utilities for authentication Lambda functions"
  
  source_code_hash = filebase64sha256("${path.module}/../../layers/shared-utils.zip")
  
  tags = var.tags
}
  # Lambda Functions Module for iOS Authentication System
# This module now works with SAM-deployed Lambda functions

# Note: Core Lambda functions, API Gateway, and DynamoDB are now managed by SAM
# This module provides additional integrations and monitoring for the SAM stack

# Data source to get SAM stack outputs
data "aws_cloudformation_stack" "sam_stack" {
  name = var.sam_stack_name
}

# Additional Lambda Layer for shared utilities (if needed)
resource "aws_lambda_layer_version" "shared_utils" {
  count = var.create_shared_layer ? 1 : 0
  
  filename   = "${path.module}/../../layers/shared-utils.zip"
  layer_name = "${var.project_name}-${var.environment}-shared-utils"
  
  compatible_runtimes = ["nodejs18.x"]
  description        = "Shared utilities for authentication Lambda functions"
  
  source_code_hash = filebase64sha256("${path.module}/../../layers/shared-utils.zip")
  
  tags = var.tags
}

# Additional CloudWatch Alarms for enhanced monitoring
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
  alarm_actions       = var.alarm_sns_topic != null ? [var.alarm_sns_topic] : []
  
  dimensions = {
    ApiName = data.aws_cloudformation_stack.sam_stack.outputs["AuthApiName"]
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
  threshold           = "1000"  # 1 second
  alarm_description   = "This metric monitors API Gateway latency"
  alarm_actions       = var.alarm_sns_topic != null ? [var.alarm_sns_topic] : []
  
  dimensions = {
    ApiName = data.aws_cloudformation_stack.sam_stack.outputs["AuthApiName"]
  }
  
  tags = var.tags
}

# EventBridge rules for monitoring SAM-deployed Lambda functions
resource "aws_cloudwatch_event_rule" "lambda_errors" {
  name        = "${var.project_name}-${var.environment}-lambda-error-rule"
  description = "Capture Lambda errors from SAM-deployed functions"
  
  event_pattern = jsonencode({
    source        = ["aws.lambda"]
    detail-type   = ["Lambda Function Invocation Result - Failure"]
    detail = {
      functionName = [
        {
          prefix = "${var.project_name}-${var.environment}-"
        }
      ]
    }
  })
  
  tags = var.tags
}

# SNS topic for error notifications
resource "aws_sns_topic" "lambda_errors" {
  count = var.create_error_notifications ? 1 : 0
  
  name = "${var.project_name}-${var.environment}-lambda-errors"
  
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "sns" {
  count = var.create_error_notifications ? 1 : 0
  
  rule      = aws_cloudwatch_event_rule.lambda_errors.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.lambda_errors[0].arn
}
