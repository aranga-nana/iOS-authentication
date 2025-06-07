# SAM Stack Integration Outputs

output "sam_stack_outputs" {
  description = "Outputs from the SAM CloudFormation stack"
  value       = data.aws_cloudformation_stack.sam_stack.outputs
}

output "sam_stack_id" {
  description = "ID of the SAM CloudFormation stack"
  value       = data.aws_cloudformation_stack.sam_stack.id
}

output "shared_layer_arn" {
  description = "ARN of the shared Lambda layer (if created)"
  value       = var.create_shared_layer ? aws_lambda_layer_version.shared_utils[0].arn : null
}

output "error_notification_topic_arn" {
  description = "ARN of the error notification SNS topic (if created)"
  value       = var.create_error_notifications ? aws_sns_topic.lambda_errors[0].arn : null
}

output "monitoring_alarms" {
  description = "CloudWatch alarm names for monitoring"
  value = {
      api_errors  = aws_cloudwatch_metric_alarm.api_gateway_errors.alarm_name
    api_latency = aws_cloudwatch_metric_alarm.api_gateway_latency.alarm_name
  }
}
