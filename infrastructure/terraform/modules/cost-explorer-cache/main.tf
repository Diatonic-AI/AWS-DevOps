# Cost Explorer Cache Tables
# Terraform module to create DynamoDB tables for caching Cost Explorer API results

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Local variables
locals {
  common_tags = {
    Module      = "cost-explorer-cache"
    Environment = var.environment
    Project     = "aws-devops"
    ManagedBy   = "terraform"
    Purpose     = "cost-optimization"
  }
}

# Partner Dashboard Cost Cache Table
resource "aws_dynamodb_table" "partner_dashboard_cache" {
  name         = "${var.environment}-partner-dashboard-cost-cache"
  billing_mode = "PAY_PER_REQUEST" # Cost-optimized billing
  hash_key     = "cache_key"

  attribute {
    name = "cache_key"
    type = "S"
  }

  # Enable TTL for automatic cleanup
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  # Point-in-time recovery for data protection
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  # Server-side encryption
  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_id != "" ? var.kms_key_id : null
  }

  tags = merge(local.common_tags, {
    Name = "${var.environment}-partner-dashboard-cost-cache"
    Type = "cache-table"
  })
}

# Client Billing Cost Cache Table
resource "aws_dynamodb_table" "client_billing_cache" {
  name         = "${var.environment}-client-billing-cost-cache"
  billing_mode = "PAY_PER_REQUEST" # Cost-optimized billing
  hash_key     = "cache_key"

  attribute {
    name = "cache_key"
    type = "S"
  }

  # Enable TTL for automatic cleanup
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  # Point-in-time recovery for data protection
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  # Server-side encryption
  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_id != "" ? var.kms_key_id : null
  }

  tags = merge(local.common_tags, {
    Name = "${var.environment}-client-billing-cost-cache"
    Type = "cache-table"
  })
}

# IAM role for Lambda functions to access cache tables
resource "aws_iam_role" "lambda_cache_access" {
  name = "${var.environment}-lambda-cost-cache-access"

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

  tags = merge(local.common_tags, {
    Name = "${var.environment}-lambda-cost-cache-access"
    Type = "iam-role"
  })
}

# IAM policy for DynamoDB cache access
resource "aws_iam_policy" "lambda_cache_policy" {
  name        = "${var.environment}-lambda-cost-cache-policy"
  description = "Allows Lambda functions to access Cost Explorer cache tables"

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
        Resource = [
          aws_dynamodb_table.partner_dashboard_cache.arn,
          aws_dynamodb_table.client_billing_cache.arn,
          "${aws_dynamodb_table.partner_dashboard_cache.arn}/index/*",
          "${aws_dynamodb_table.client_billing_cache.arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*"
      }
    ]
  })

  tags = local.common_tags
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "lambda_cache_policy_attach" {
  role       = aws_iam_role.lambda_cache_access.name
  policy_arn = aws_iam_policy.lambda_cache_policy.arn
}

# CloudWatch Alarms for monitoring cache performance
resource "aws_cloudwatch_metric_alarm" "partner_cache_throttles" {
  alarm_name          = "${var.environment}-partner-cache-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "SystemErrors"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors partner dashboard cache throttles"
  alarm_actions       = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    TableName = aws_dynamodb_table.partner_dashboard_cache.name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "client_cache_throttles" {
  alarm_name          = "${var.environment}-client-cache-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "SystemErrors"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors client billing cache throttles"
  alarm_actions       = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    TableName = aws_dynamodb_table.client_billing_cache.name
  }

  tags = local.common_tags
}

# Output cache table information for cost monitoring
resource "aws_cloudwatch_dashboard" "cost_optimization" {
  count          = var.create_dashboard ? 1 : 0
  dashboard_name = "${var.environment}-cost-explorer-optimization"

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
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", aws_dynamodb_table.partner_dashboard_cache.name],
            [".", "ConsumedWriteCapacityUnits", ".", "."],
            [".", "ConsumedReadCapacityUnits", "TableName", aws_dynamodb_table.client_billing_cache.name],
            [".", "ConsumedWriteCapacityUnits", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          period  = 300
          title   = "Cost Explorer Cache Usage"
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
            ["AWS/DynamoDB", "ItemCount", "TableName", aws_dynamodb_table.partner_dashboard_cache.name],
            [".", ".", ".", aws_dynamodb_table.client_billing_cache.name]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          period  = 3600
          title   = "Cache Item Counts"
        }
      }
    ]
  })
}
