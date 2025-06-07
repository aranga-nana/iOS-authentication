output "function_arns" {
  description = "ARNs of the Lambda functions"
  value = {
    for k, v in aws_lambda_function.functions : k => v.arn
  }
}

output "function_names" {
  description = "Names of the Lambda functions"
  value = {
    for k, v in aws_lambda_function.functions : k => v.function_name
  }
}

output "function_invoke_arns" {
  description = "Invoke ARNs of the Lambda functions"
  value = {
    for k, v in aws_lambda_function.functions : k => v.invoke_arn
  }
}

output "function_qualified_arns" {
  description = "Qualified ARNs of the Lambda functions"
  value = {
    for k, v in aws_lambda_function.functions : k => v.qualified_arn
  }
}

output "function_versions" {
  description = "Versions of the Lambda functions"
  value = {
    for k, v in aws_lambda_function.functions : k => v.version
  }
}

output "function_alias_arns" {
  description = "ARNs of the Lambda function aliases"
  value = {
    for k, v in aws_lambda_alias.live : k => v.arn
  }
}

output "execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.arn
}

output "execution_role_name" {
  description = "Name of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.name
}

output "log_group_names" {
  description = "Names of the CloudWatch log groups"
  value = {
    for k, v in aws_cloudwatch_log_group.lambda_logs : k => v.name
  }
}

output "log_group_arns" {
  description = "ARNs of the CloudWatch log groups"
  value = {
    for k, v in aws_cloudwatch_log_group.lambda_logs : k => v.arn
  }
}

output "dlq_arns" {
  description = "ARNs of the dead letter queues"
  value = {
    for k, v in aws_sqs_queue.dlq : k => v.arn
  }
}

output "dlq_urls" {
  description = "URLs of the dead letter queues"
  value = {
    for k, v in aws_sqs_queue.dlq : k => v.url
  }
}

output "lambda_bucket_name" {
  description = "Name of the S3 bucket for Lambda deployments"
  value       = aws_s3_bucket.lambda_deployments.bucket
}

output "lambda_bucket_arn" {
  description = "ARN of the S3 bucket for Lambda deployments"
  value       = aws_s3_bucket.lambda_deployments.arn
}

output "layer_arn" {
  description = "ARN of the Lambda layer (if created)"
  value       = var.create_shared_layer ? aws_lambda_layer_version.dependencies[0].arn : null
}

output "alarm_names" {
  description = "Names of the CloudWatch alarms"
  value = {
    errors    = { for k, v in aws_cloudwatch_metric_alarm.lambda_errors : k => v.alarm_name }
    duration  = { for k, v in aws_cloudwatch_metric_alarm.lambda_duration : k => v.alarm_name }
    throttles = { for k, v in aws_cloudwatch_metric_alarm.lambda_throttles : k => v.alarm_name }
  }
}
