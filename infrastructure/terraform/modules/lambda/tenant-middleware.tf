# Tenant Middleware Lambda Function
# Handles multi-tenant context extraction, validation, and authorization

# Data source for Lambda execution role
data "aws_iam_role" "lambda_execution_role" {
  name = "${var.project_prefix}-lambda-execution-role-${var.environment}"
}

# Lambda function
resource "aws_lambda_function" "tenant_middleware" {
  filename         = var.lambda_zip_file
  function_name    = "${var.project_prefix}-tenant-middleware-${var.environment}"
  role            = data.aws_iam_role.lambda_execution_role.arn
  handler         = "index.handler"
  runtime         = "nodejs18.x"
  timeout         = 30
  memory_size     = 512

  source_code_hash = filebase64sha256(var.lambda_zip_file)

  environment {
    variables = {
      COGNITO_USER_POOL_ID    = var.cognito_user_pool_id
      COGNITO_CLIENT_ID       = var.cognito_client_id
      COGNITO_REGION          = var.aws_region
      ORGANIZATIONS_TABLE     = var.organizations_table_name
      USER_ORGS_TABLE        = var.user_orgs_table_name
      TENANT_USAGE_TABLE     = var.tenant_usage_table_name
      NODE_ENV               = var.environment
      AWS_NODEJS_CONNECTION_REUSE_ENABLED = "1"
    }
  }

  # VPC configuration for secure DynamoDB access
  vpc_config {
    subnet_ids         = var.lambda_subnet_ids
    security_group_ids = [aws_security_group.tenant_middleware_sg.id]
  }

  # Dead letter queue for failed invocations
  dead_letter_config {
    target_arn = aws_sqs_queue.tenant_middleware_dlq.arn
  }

  # Tracing configuration
  tracing_config {
    mode = "Active"
  }

  tags = merge(var.default_tags, {
    Name = "Tenant Middleware Lambda"
    Purpose = "Multi-tenant request processing"
    Component = "authentication"
  })

  depends_on = [
    aws_iam_role_policy_attachment.tenant_middleware_policy,
    aws_cloudwatch_log_group.tenant_middleware_logs
  ]
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "tenant_middleware_logs" {
  name              = "/aws/lambda/${var.project_prefix}-tenant-middleware-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id       = var.cloudwatch_kms_key_arn

  tags = var.default_tags
}

# Security Group for Lambda
resource "aws_security_group" "tenant_middleware_sg" {
  name_prefix = "${var.project_prefix}-tenant-middleware-${var.environment}"
  vpc_id      = var.vpc_id

  # Allow outbound HTTPS for API calls
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound"
  }

  # Allow outbound DNS
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DNS resolution"
  }

  tags = merge(var.default_tags, {
    Name = "Tenant Middleware Security Group"
  })
}

# IAM policy for tenant middleware Lambda
resource "aws_iam_policy" "tenant_middleware_policy" {
  name        = "${var.project_prefix}-tenant-middleware-policy-${var.environment}"
  description = "IAM policy for tenant middleware Lambda function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:UpdateItem"
        ]
        Resource = [
          var.organizations_table_arn,
          var.user_orgs_table_arn,
          var.tenant_usage_table_arn,
          "${var.organizations_table_arn}/index/*",
          "${var.user_orgs_table_arn}/index/*",
          "${var.tenant_usage_table_arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:GetUser",
          "cognito-idp:AdminGetUser",
          "cognito-idp:ListUsers"
        ]
        Resource = [
          "arn:aws:cognito-idp:${var.aws_region}:${var.aws_account_id}:userpool/${var.cognito_user_pool_id}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.tenant_middleware_dlq.arn
      },
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [
          var.dynamodb_kms_key_arn,
          var.cloudwatch_kms_key_arn
        ]
      }
    ]
  })

  tags = var.default_tags
}

# Attach policy to Lambda execution role
resource "aws_iam_role_policy_attachment" "tenant_middleware_policy" {
  role       = data.aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.tenant_middleware_policy.arn
}

# Dead Letter Queue for failed invocations
resource "aws_sqs_queue" "tenant_middleware_dlq" {
  name                       = "${var.project_prefix}-tenant-middleware-dlq-${var.environment}"
  message_retention_seconds  = 1209600  # 14 days
  visibility_timeout_seconds = 60

  kms_master_key_id = var.sqs_kms_key_arn

  tags = merge(var.default_tags, {
    Name = "Tenant Middleware DLQ"
  })
}

# Lambda Alias for versioning
resource "aws_lambda_alias" "tenant_middleware_alias" {
  name             = var.environment
  description      = "Alias for tenant middleware Lambda in ${var.environment}"
  function_name    = aws_lambda_function.tenant_middleware.function_name
  function_version = "$LATEST"

  depends_on = [aws_lambda_function.tenant_middleware]
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "tenant_middleware_errors" {
  alarm_name          = "${var.project_prefix}-tenant-middleware-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors tenant middleware Lambda errors"
  alarm_actions       = [var.sns_alarm_topic_arn]

  dimensions = {
    FunctionName = aws_lambda_function.tenant_middleware.function_name
  }

  tags = var.default_tags
}

resource "aws_cloudwatch_metric_alarm" "tenant_middleware_duration" {
  alarm_name          = "${var.project_prefix}-tenant-middleware-duration-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = "25000"  # 25 seconds (close to 30s timeout)
  alarm_description   = "This metric monitors tenant middleware Lambda duration"
  alarm_actions       = [var.sns_alarm_topic_arn]

  dimensions = {
    FunctionName = aws_lambda_function.tenant_middleware.function_name
  }

  tags = var.default_tags
}

resource "aws_cloudwatch_metric_alarm" "tenant_middleware_throttles" {
  alarm_name          = "${var.project_prefix}-tenant-middleware-throttles-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors tenant middleware Lambda throttles"
  alarm_actions       = [var.sns_alarm_topic_arn]

  dimensions = {
    FunctionName = aws_lambda_function.tenant_middleware.function_name
  }

  tags = var.default_tags
}

# Lambda permission for API Gateway to invoke
resource "aws_lambda_permission" "tenant_middleware_api_gateway" {
  count         = var.enable_api_gateway_integration ? 1 : 0
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tenant_middleware.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_gateway_execution_arn}/*/*"
}

# Custom metrics for tenant operations
resource "aws_cloudwatch_log_metric_filter" "tenant_context_extractions" {
  name           = "TenantContextExtractions"
  log_group_name = aws_cloudwatch_log_group.tenant_middleware_logs.name
  pattern        = "[timestamp, request_id, level=\"INFO\", message=\"Tenant context extracted\", ...]"

  metric_transformation {
    name      = "TenantContextExtractions"
    namespace = "AI-Nexus/TenantMiddleware"
    value     = "1"
    default_value = 0
  }
}

resource "aws_cloudwatch_log_metric_filter" "unauthorized_attempts" {
  name           = "UnauthorizedAttempts"
  log_group_name = aws_cloudwatch_log_group.tenant_middleware_logs.name
  pattern        = "[timestamp, request_id, level=\"ERROR\", message=\"UnauthorizedError*\", ...]"

  metric_transformation {
    name      = "UnauthorizedAttempts"
    namespace = "AI-Nexus/Security"
    value     = "1"
    default_value = 0
  }
}

resource "aws_cloudwatch_log_metric_filter" "cross_tenant_access_denied" {
  name           = "CrossTenantAccessDenied"
  log_group_name = aws_cloudwatch_log_group.tenant_middleware_logs.name
  pattern        = "[timestamp, request_id, level=\"ERROR\", message=\"User does not belong to this organization\", ...]"

  metric_transformation {
    name      = "CrossTenantAccessDenied"
    namespace = "AI-Nexus/Security"
    value     = "1"
    default_value = 0
  }
}

# Variables
variable "lambda_zip_file" {
  description = "Path to the Lambda function zip file"
  type        = string
}

variable "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  type        = string
}

variable "cognito_client_id" {
  description = "Cognito User Pool Client ID"
  type        = string
}

variable "organizations_table_name" {
  description = "Name of the organizations DynamoDB table"
  type        = string
}

variable "organizations_table_arn" {
  description = "ARN of the organizations DynamoDB table"
  type        = string
}

variable "user_orgs_table_name" {
  description = "Name of the user-organizations DynamoDB table"
  type        = string
}

variable "user_orgs_table_arn" {
  description = "ARN of the user-organizations DynamoDB table"
  type        = string
}

variable "tenant_usage_table_name" {
  description = "Name of the tenant usage DynamoDB table"
  type        = string
}

variable "tenant_usage_table_arn" {
  description = "ARN of the tenant usage DynamoDB table"
  type        = string
}

variable "lambda_subnet_ids" {
  description = "List of subnet IDs for Lambda VPC configuration"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID for security group"
  type        = string
}

variable "log_retention_days" {
  description = "Log retention period in days"
  type        = number
  default     = 14
}

variable "enable_api_gateway_integration" {
  description = "Enable API Gateway integration"
  type        = bool
  default     = true
}

variable "api_gateway_execution_arn" {
  description = "API Gateway execution ARN"
  type        = string
  default     = ""
}

variable "sns_alarm_topic_arn" {
  description = "SNS topic ARN for alarms"
  type        = string
}

variable "dynamodb_kms_key_arn" {
  description = "KMS key ARN for DynamoDB encryption"
  type        = string
}

variable "cloudwatch_kms_key_arn" {
  description = "KMS key ARN for CloudWatch encryption"
  type        = string
}

variable "sqs_kms_key_arn" {
  description = "KMS key ARN for SQS encryption"
  type        = string
}

variable "project_prefix" {
  description = "Project prefix for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Outputs
output "lambda_function_arn" {
  description = "ARN of the tenant middleware Lambda function"
  value       = aws_lambda_function.tenant_middleware.arn
}

output "lambda_function_name" {
  description = "Name of the tenant middleware Lambda function"
  value       = aws_lambda_function.tenant_middleware.function_name
}

output "lambda_invoke_arn" {
  description = "Invoke ARN of the tenant middleware Lambda function"
  value       = aws_lambda_function.tenant_middleware.invoke_arn
}

output "security_group_id" {
  description = "Security group ID for the Lambda function"
  value       = aws_security_group.tenant_middleware_sg.id
}

output "dead_letter_queue_arn" {
  description = "ARN of the dead letter queue"
  value       = aws_sqs_queue.tenant_middleware_dlq.arn
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.tenant_middleware_logs.name
}
