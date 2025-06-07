output "api_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_url" {
  description = "API Gateway invoke URL"
  value       = "https://${aws_api_gateway_rest_api.main.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.main.stage_name}"
}

output "api_arn" {
  description = "API Gateway REST API ARN"
  value       = aws_api_gateway_rest_api.main.arn
}

output "stage_name" {
  description = "API Gateway stage name"
  value       = aws_api_gateway_stage.main.stage_name
}

output "stage_arn" {
  description = "API Gateway stage ARN"
  value       = aws_api_gateway_stage.main.arn
}

output "execution_arn" {
  description = "API Gateway execution ARN"
  value       = aws_api_gateway_rest_api.main.execution_arn
}

output "deployment_id" {
  description = "API Gateway deployment ID"
  value       = aws_api_gateway_deployment.main.id
}

output "custom_domain_name" {
  description = "Custom domain name (if configured)"
  value       = var.domain_name != null ? aws_api_gateway_domain_name.main[0].domain_name : null
}

output "custom_domain_url" {
  description = "Custom domain URL (if configured)"
  value       = var.domain_name != null ? "https://${aws_api_gateway_domain_name.main[0].domain_name}" : null
}

output "log_group_name" {
  description = "CloudWatch log group name for API Gateway"
  value       = aws_cloudwatch_log_group.api_gateway.name
}

output "log_group_arn" {
  description = "CloudWatch log group ARN for API Gateway"
  value       = aws_cloudwatch_log_group.api_gateway.arn
}

# Data source for current AWS region
data "aws_region" "current" {}
