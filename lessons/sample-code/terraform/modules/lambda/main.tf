# Lambda Functions Module for iOS Authentication System

# Data source for Lambda function zip
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../sample-code/aws-lambda"
  output_path = "${path.module}/lambda-functions.zip"
  excludes    = [
    "node_modules",
    ".env",
    ".env.example",
    "*.test.js",
    "__tests__",
    "coverage",
    ".nyc_output",
    "README.md",
    ".git"
  ]
}

# S3 bucket for Lambda deployment packages
resource "aws_s3_bucket" "lambda_deployments" {
  bucket = "${var.project_name}-${var.environment}-lambda-deployments-${random_string.bucket_suffix.result}"
  
  tags = var.tags
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

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Upload Lambda function code
resource "aws_s3_object" "lambda_zip" {
  bucket = aws_s3_bucket.lambda_deployments.bucket
  key    = "lambda-functions-${filemd5(data.archive_file.lambda_zip.output_path)}.zip"
  source = data.archive_file.lambda_zip.output_path
  etag   = filemd5(data.archive_file.lambda_zip.output_path)
  
  depends_on = [
    aws_s3_bucket_server_side_encryption_configuration.lambda_deployments
  ]
}

# CloudWatch Log Groups for Lambda functions
resource "aws_cloudwatch_log_group" "lambda_logs" {
  for_each = var.function_names
  
  name              = "/aws/lambda/${var.project_name}-${var.environment}-${each.value}"
  retention_in_days = var.log_retention_days
  
  tags = var.tags
}

# IAM role for Lambda functions
resource "aws_iam_role" "lambda_execution" {
  name = "${var.project_name}-${var.environment}-lambda-execution"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.tags
}

# IAM policy for Lambda basic execution
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM policy for DynamoDB access
resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "${var.project_name}-${var.environment}-lambda-dynamodb"
  role = aws_iam_role.lambda_execution.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = var.dynamodb_table_arns
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          for arn in var.dynamodb_table_arns : "${arn}/index/*"
        ]
      }
    ]
  })
}

# IAM policy for CloudWatch metrics
resource "aws_iam_role_policy" "lambda_cloudwatch" {
  name = "${var.project_name}-${var.environment}-lambda-cloudwatch"
  role = aws_iam_role.lambda_execution.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM policy for X-Ray tracing (optional)
resource "aws_iam_role_policy_attachment" "lambda_xray" {
  count = var.enable_xray_tracing ? 1 : 0
  
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# Lambda functions
resource "aws_lambda_function" "functions" {
  for_each = var.function_names
  
  function_name    = "${var.project_name}-${var.environment}-${each.value}"
  role            = aws_iam_role.lambda_execution.arn
  handler         = "userFunctions.${each.key}"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime         = var.runtime
  timeout         = var.timeout
  memory_size     = var.memory_size
  
  # Use S3 for deployment package
  s3_bucket = aws_s3_bucket.lambda_deployments.bucket
  s3_key    = aws_s3_object.lambda_zip.key
  
  # Environment variables
  environment {
    variables = merge(
      var.environment_variables,
      {
        FUNCTION_NAME = each.value
        STAGE         = var.environment
      }
    )
  }
  
  # VPC configuration (if needed)
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }
  
  # Dead letter queue configuration
  dead_letter_config {
    target_arn = aws_sqs_queue.dlq[each.key].arn
  }
  
  # X-Ray tracing
  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }
  
  # Reserved concurrency
  reserved_concurrent_executions = var.reserved_concurrency[each.key]
  
  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy.lambda_dynamodb,
    aws_iam_role_policy.lambda_cloudwatch,
    aws_cloudwatch_log_group.lambda_logs,
    aws_s3_object.lambda_zip
  ]
  
  tags = var.tags
}

# Dead Letter Queues for Lambda functions
resource "aws_sqs_queue" "dlq" {
  for_each = var.function_names
  
  name                      = "${var.project_name}-${var.environment}-${each.value}-dlq"
  message_retention_seconds = 1209600  # 14 days
  
  tags = var.tags
}

# CloudWatch Alarms for Lambda functions
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = var.function_names
  
  alarm_name          = "${var.project_name}-${var.environment}-${each.value}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors lambda errors for ${each.value}"
  alarm_actions       = var.alarm_sns_topic != null ? [var.alarm_sns_topic] : []
  
  dimensions = {
    FunctionName = aws_lambda_function.functions[each.key].function_name
  }
  
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  for_each = var.function_names
  
  alarm_name          = "${var.project_name}-${var.environment}-${each.value}-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = tostring(var.timeout * 1000 * 0.8)  # 80% of timeout
  alarm_description   = "This metric monitors lambda duration for ${each.value}"
  alarm_actions       = var.alarm_sns_topic != null ? [var.alarm_sns_topic] : []
  
  dimensions = {
    FunctionName = aws_lambda_function.functions[each.key].function_name
  }
  
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  for_each = var.function_names
  
  alarm_name          = "${var.project_name}-${var.environment}-${each.value}-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors lambda throttles for ${each.value}"
  alarm_actions       = var.alarm_sns_topic != null ? [var.alarm_sns_topic] : []
  
  dimensions = {
    FunctionName = aws_lambda_function.functions[each.key].function_name
  }
  
  tags = var.tags
}

# Lambda function aliases for blue-green deployments
resource "aws_lambda_alias" "live" {
  for_each = var.function_names
  
  name             = "live"
  description      = "Live alias for ${each.value}"
  function_name    = aws_lambda_function.functions[each.key].function_name
  function_version = aws_lambda_function.functions[each.key].version
  
  depends_on = [aws_lambda_function.functions]
}

# EventBridge rules for monitoring
resource "aws_cloudwatch_event_rule" "lambda_errors" {
  for_each = var.function_names
  
  name        = "${var.project_name}-${var.environment}-${each.value}-error-rule"
  description = "Capture Lambda errors for ${each.value}"
  
  event_pattern = jsonencode({
    source        = ["aws.lambda"]
    detail-type   = ["Lambda Function Invocation Result - Failure"]
    detail = {
      functionName = [aws_lambda_function.functions[each.key].function_name]
    }
  })
  
  tags = var.tags
}

# Lambda layers for shared code
resource "aws_lambda_layer_version" "dependencies" {
  count = var.create_shared_layer ? 1 : 0
  
  filename   = data.archive_file.lambda_layer[0].output_path
  layer_name = "${var.project_name}-${var.environment}-dependencies"
  
  compatible_runtimes = [var.runtime]
  
  depends_on = [data.archive_file.lambda_layer]
}

data "archive_file" "lambda_layer" {
  count = var.create_shared_layer ? 1 : 0
  
  type        = "zip"
  output_path = "${path.module}/lambda-layer.zip"
  
  source {
    content  = file("${path.module}/../../sample-code/aws-lambda/package.json")
    filename = "nodejs/package.json"
  }
}
