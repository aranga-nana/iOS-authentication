output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.name
}

output "dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "log_group_names" {
  description = "Names of monitored log groups"
  value = [
    for func_name in var.lambda_function_names : 
    "/aws/lambda/${func_name}"
  ]
}

output "alarm_names" {
  description = "Names of CloudWatch alarms"
  value = {
    api_errors              = aws_cloudwatch_metric_alarm.api_gateway_errors.alarm_name
    api_server_errors      = aws_cloudwatch_metric_alarm.api_gateway_server_errors.alarm_name
    api_latency            = aws_cloudwatch_metric_alarm.api_gateway_latency.alarm_name
    authentication_failures = aws_cloudwatch_metric_alarm.authentication_failures.alarm_name
    rate_limit_exceeded    = aws_cloudwatch_metric_alarm.rate_limit_exceeded.alarm_name
    dynamodb_read_throttles = [
      for alarm in aws_cloudwatch_metric_alarm.dynamodb_read_throttles : alarm.alarm_name
    ]
    dynamodb_write_throttles = [
      for alarm in aws_cloudwatch_metric_alarm.dynamodb_write_throttles : alarm.alarm_name
    ]
  }
}

output "query_definition_names" {
  description = "Names of CloudWatch Insights query definitions"
  value = {
    error_analysis       = aws_cloudwatch_query_definition.error_analysis.name
    performance_analysis = aws_cloudwatch_query_definition.performance_analysis.name
    security_events     = aws_cloudwatch_query_definition.security_events.name
  }
}

output "xray_sampling_rule_arn" {
  description = "ARN of the X-Ray sampling rule (if enabled)"
  value       = var.enable_xray_tracing ? aws_xray_sampling_rule.main[0].arn : null
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule for Lambda state changes"
  value       = aws_cloudwatch_event_rule.lambda_state_change.arn
}

output "metric_filter_names" {
  description = "Names of CloudWatch log metric filters"
  value = {
    error_count            = aws_cloudwatch_log_metric_filter.error_count.name
    authentication_failures = aws_cloudwatch_log_metric_filter.authentication_failures.name
    rate_limit_exceeded    = aws_cloudwatch_log_metric_filter.rate_limit_exceeded.name
  }
}

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
