# Observability Module
# CloudWatch, X-Ray, and alerting configuration

variable "name" {
  type = string
}

variable "tags" {
  type = map(string)
}

# Log groups for services
resource "aws_cloudwatch_log_group" "api" {
  name              = "/pcw/${var.name}/api"
  retention_in_days = 30

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "connectors" {
  name              = "/pcw/${var.name}/connectors"
  retention_in_days = 30

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "orchestration" {
  name              = "/pcw/${var.name}/orchestration"
  retention_in_days = 30

  tags = var.tags
}

# Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.name}-platform"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title = "API Requests"
          view  = "timeSeries"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiId", "placeholder"]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title = "Step Functions Executions"
          view  = "timeSeries"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/States", "ExecutionsSucceeded"],
            [".", "ExecutionsFailed"]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title = "Database Connections"
          view  = "timeSeries"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/RDS", "DatabaseConnections"]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title = "S3 Storage"
          view  = "timeSeries"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/S3", "BucketSizeBytes", "StorageType", "StandardStorage"]
          ]
        }
      }
    ]
  })
}

# SNS Topic for alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.name}-alerts"

  tags = var.tags
}

# CloudWatch alarm for high error rate
resource "aws_cloudwatch_metric_alarm" "api_errors" {
  alarm_name          = "${var.name}-api-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "API Gateway 5XX errors exceeded threshold"

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = var.tags
}

data "aws_region" "current" {}

output "api_log_group" {
  value = aws_cloudwatch_log_group.api.name
}

output "connectors_log_group" {
  value = aws_cloudwatch_log_group.connectors.name
}

output "alerts_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "dashboard_url" {
  value = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}
