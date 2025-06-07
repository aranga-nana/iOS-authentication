# DynamoDB Module for iOS Authentication System
# NOTE: Core DynamoDB tables are now managed by AWS SAM
# This module provides additional DynamoDB configurations and monitoring

# Data source to reference SAM-deployed DynamoDB table
data "aws_dynamodb_table" "sam_users_table" {
  name = var.sam_users_table_name
}

# Additional DynamoDB tables for extended functionality (if needed)
resource "aws_dynamodb_table" "additional_tables" {
  for_each = var.additional_tables
  
  name           = "${var.project_name}-${each.key}-${var.environment}"
  billing_mode   = var.billing_mode
  hash_key       = each.value.hash_key
  range_key      = lookup(each.value, "range_key", null)
  
  # Capacity settings for provisioned billing mode
  read_capacity  = var.billing_mode == "PROVISIONED" ? var.read_capacity : null
  write_capacity = var.billing_mode == "PROVISIONED" ? var.write_capacity : null
  
  # Attributes
  dynamic "attribute" {
    for_each = each.value.attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }
    content {
      name            = global_secondary_index.value.name
      hash_key        = global_secondary_index.value.hash_key
      range_key       = lookup(global_secondary_index.value, "range_key", null)
      projection_type = lookup(global_secondary_index.value, "projection_type", "ALL")
      
      # Capacity for provisioned billing
      read_capacity  = var.billing_mode == "PROVISIONED" ? lookup(global_secondary_index.value, "read_capacity", 5) : null
      write_capacity = var.billing_mode == "PROVISIONED" ? lookup(global_secondary_index.value, "write_capacity", 5) : null
    }
  }
  
  # Local Secondary Indexes
  dynamic "local_secondary_index" {
    for_each = lookup(each.value, "local_secondary_indexes", [])
    content {
      name            = local_secondary_index.value.name
      range_key       = local_secondary_index.value.range_key
      projection_type = lookup(local_secondary_index.value, "projection_type", "ALL")
    }
  }
  
  # TTL Configuration
  dynamic "ttl" {
    for_each = lookup(each.value, "ttl_attribute", null) != null ? [1] : []
    content {
      attribute_name = each.value.ttl_attribute
      enabled        = true
    }
  }
  
  # Stream Configuration
  stream_enabled   = lookup(each.value, "stream_enabled", false)
  stream_view_type = lookup(each.value, "stream_enabled", false) ? lookup(each.value, "stream_view_type", "NEW_AND_OLD_IMAGES") : null
  
  # Point-in-time Recovery
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }
  
  # Server-side Encryption
  server_side_encryption {
    enabled     = true
    kms_key_id  = var.kms_key_id != null ? var.kms_key_id : "alias/aws/dynamodb"
  }
  
  # Deletion Protection
  deletion_protection_enabled = var.enable_deletion_protection
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-${each.key}-${var.environment}"
    Type = "DynamoDB Table"
  })
  
  lifecycle {
    prevent_destroy = false
  }
}

# Auto Scaling for Provisioned Tables
resource "aws_appautoscaling_target" "read_target" {
  for_each = var.billing_mode == "PROVISIONED" && var.enable_autoscaling ? var.tables : {}
  
  max_capacity       = var.max_read_capacity
  min_capacity       = var.min_read_capacity
  resource_id        = "table/${aws_dynamodb_table.tables[each.key].name}"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_target" "write_target" {
  for_each = var.billing_mode == "PROVISIONED" && var.enable_autoscaling ? var.tables : {}
  
  max_capacity       = var.max_write_capacity
  min_capacity       = var.min_write_capacity
  resource_id        = "table/${aws_dynamodb_table.tables[each.key].name}"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "read_policy" {
  for_each = var.billing_mode == "PROVISIONED" && var.enable_autoscaling ? var.tables : {}
  
  name               = "${aws_dynamodb_table.tables[each.key].name}-read-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.read_target[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.read_target[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.read_target[each.key].service_namespace
  
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }
    target_value = var.target_utilization
  }
}

resource "aws_appautoscaling_policy" "write_policy" {
  for_each = var.billing_mode == "PROVISIONED" && var.enable_autoscaling ? var.tables : {}
  
  name               = "${aws_dynamodb_table.tables[each.key].name}-write-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.write_target[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.write_target[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.write_target[each.key].service_namespace
  
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }
    target_value = var.target_utilization
  }
}

# Backup Configuration
resource "aws_dynamodb_table_backup" "backup" {
  for_each = var.enable_automated_backups ? var.tables : {}
  
  table_name = aws_dynamodb_table.tables[each.key].name
  name       = "${aws_dynamodb_table.tables[each.key].name}-backup-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  
  tags = var.tags
}

# CloudWatch Alarms for DynamoDB
resource "aws_cloudwatch_metric_alarm" "read_throttled_requests" {
  for_each = var.enable_cloudwatch_alarms ? var.tables : {}
  
  alarm_name          = "${aws_dynamodb_table.tables[each.key].name}-read-throttled-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ReadThrottledEvents"
  namespace           = "AWS/DynamoDB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors read throttled requests"
  alarm_actions       = var.alarm_actions
  
  dimensions = {
    TableName = aws_dynamodb_table.tables[each.key].name
  }
  
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "write_throttled_requests" {
  for_each = var.enable_cloudwatch_alarms ? var.tables : {}
  
  alarm_name          = "${aws_dynamodb_table.tables[each.key].name}-write-throttled-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "WriteThrottledEvents"
  namespace           = "AWS/DynamoDB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors write throttled requests"
  alarm_actions       = var.alarm_actions
  
  dimensions = {
    TableName = aws_dynamodb_table.tables[each.key].name
  }
  
  tags = var.tags
}
