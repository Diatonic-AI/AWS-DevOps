# Eventing Module
# EventBridge bus, rules, and DLQ configuration

variable "name" {
  type = string
}

variable "tags" {
  type = map(string)
}

# Custom EventBridge bus
resource "aws_cloudwatch_event_bus" "main" {
  name = "${var.name}-events"

  tags = var.tags
}

# Dead Letter Queue for failed events
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.name}-events-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = merge(var.tags, {
    Name = "${var.name}-events-dlq"
  })
}

# DLQ policy
resource "aws_sqs_queue_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridge"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.dlq.arn
      }
    ]
  })
}

# Archive for event replay
resource "aws_cloudwatch_event_archive" "main" {
  name             = "${var.name}-archive"
  event_source_arn = aws_cloudwatch_event_bus.main.arn
  retention_days   = 90
}

output "bus_name" {
  value = aws_cloudwatch_event_bus.main.name
}

output "bus_arn" {
  value = aws_cloudwatch_event_bus.main.arn
}

output "dlq_arn" {
  value = aws_sqs_queue.dlq.arn
}

output "dlq_url" {
  value = aws_sqs_queue.dlq.url
}
