# DynamoDB Table for AI Nexus User Data
resource "aws_dynamodb_table" "ai_nexus_user_data" {
  name           = "${var.project_name}-${var.environment}-ai-nexus-user-data"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "userId"
  range_key      = "dataType"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "dataType"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  # Global Secondary Index for querying by data type and creation time
  global_secondary_index {
    name            = "DataTypeIndex"
    hash_key        = "dataType"
    range_key       = "createdAt"
    projection_type = "ALL"
  }

  # Global Secondary Index for querying by status
  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "userId"
    range_key       = "status"
    projection_type = "ALL"
  }

  # Enable point-in-time recovery
  point_in_time_recovery {
    enabled = true
  }

  # Server-side encryption
  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ai-nexus-user-data"
    Environment = var.environment
    Project     = var.project_name
    Application = "ai-nexus-workbench"
  }
}

# DynamoDB Table for AI Nexus Application State
resource "aws_dynamodb_table" "ai_nexus_app_state" {
  name           = "${var.project_name}-${var.environment}-ai-nexus-app-state"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "userId"
  range_key      = "stateKey"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "stateKey"
    type = "S"
  }

  attribute {
    name = "lastModified"
    type = "S"
  }

  # Global Secondary Index for querying by last modified time
  global_secondary_index {
    name            = "LastModifiedIndex"
    hash_key        = "userId"
    range_key       = "lastModified"
    projection_type = "ALL"
  }

  # TTL attribute for automatic cleanup of temporary state
  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }

  # Enable point-in-time recovery
  point_in_time_recovery {
    enabled = true
  }

  # Server-side encryption
  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ai-nexus-app-state"
    Environment = var.environment
    Project     = var.project_name
    Application = "ai-nexus-workbench"
  }
}

# DynamoDB Table for AI Nexus Sessions/Analytics
resource "aws_dynamodb_table" "ai_nexus_sessions" {
  name           = "${var.project_name}-${var.environment}-ai-nexus-sessions"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "sessionId"

  attribute {
    name = "sessionId"
    type = "S"
  }

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }

  # Global Secondary Index for querying sessions by user
  global_secondary_index {
    name            = "UserSessionsIndex"
    hash_key        = "userId"
    range_key       = "createdAt"
    projection_type = "ALL"
  }

  # TTL attribute for automatic cleanup of old sessions
  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }

  # Enable point-in-time recovery
  point_in_time_recovery {
    enabled = true
  }

  # Server-side encryption
  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ai-nexus-sessions"
    Environment = var.environment
    Project     = var.project_name
    Application = "ai-nexus-workbench"
  }
}

# DynamoDB Table for AI Nexus File Metadata
resource "aws_dynamodb_table" "ai_nexus_files" {
  name           = "${var.project_name}-${var.environment}-ai-nexus-files"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "fileId"
  range_key      = "version"

  attribute {
    name = "fileId"
    type = "S"
  }

  attribute {
    name = "version"
    type = "N"
  }

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "uploadedAt"
    type = "S"
  }

  attribute {
    name = "fileType"
    type = "S"
  }

  # Global Secondary Index for querying files by user
  global_secondary_index {
    name            = "UserFilesIndex"
    hash_key        = "userId"
    range_key       = "uploadedAt"
    projection_type = "ALL"
  }

  # Global Secondary Index for querying files by type
  global_secondary_index {
    name            = "FileTypeIndex"
    hash_key        = "fileType"
    range_key       = "uploadedAt"
    projection_type = "INCLUDE"
    non_key_attributes = ["fileId", "userId", "fileName", "fileSize"]
  }

  # Enable point-in-time recovery
  point_in_time_recovery {
    enabled = true
  }

  # Server-side encryption
  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ai-nexus-files"
    Environment = var.environment
    Project     = var.project_name
    Application = "ai-nexus-workbench"
  }
}

# IAM role for Lambda functions to access DynamoDB
resource "aws_iam_role" "ai_nexus_lambda_dynamodb_role" {
  name = "${var.project_name}-${var.environment}-ai-nexus-lambda-dynamodb-role"

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

  tags = {
    Name        = "${var.project_name}-${var.environment}-ai-nexus-lambda-dynamodb-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM policy for Lambda to access DynamoDB tables
resource "aws_iam_policy" "ai_nexus_lambda_dynamodb_policy" {
  name        = "${var.project_name}-${var.environment}-ai-nexus-lambda-dynamodb-policy"
  description = "Policy for Lambda functions to access AI Nexus DynamoDB tables"

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
          "dynamodb:BatchWriteItem",
          "dynamodb:DescribeTable"
        ]
        Resource = [
          aws_dynamodb_table.ai_nexus_user_data.arn,
          "${aws_dynamodb_table.ai_nexus_user_data.arn}/index/*",
          aws_dynamodb_table.ai_nexus_app_state.arn,
          "${aws_dynamodb_table.ai_nexus_app_state.arn}/index/*",
          aws_dynamodb_table.ai_nexus_sessions.arn,
          "${aws_dynamodb_table.ai_nexus_sessions.arn}/index/*",
          aws_dynamodb_table.ai_nexus_files.arn,
          "${aws_dynamodb_table.ai_nexus_files.arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "ai_nexus_lambda_dynamodb_policy_attachment" {
  role       = aws_iam_role.ai_nexus_lambda_dynamodb_role.name
  policy_arn = aws_iam_policy.ai_nexus_lambda_dynamodb_policy.arn
}

# Outputs
output "ai_nexus_dynamodb_user_data_table_name" {
  description = "Name of the DynamoDB table for user data"
  value       = aws_dynamodb_table.ai_nexus_user_data.name
}

output "ai_nexus_dynamodb_user_data_table_arn" {
  description = "ARN of the DynamoDB table for user data"
  value       = aws_dynamodb_table.ai_nexus_user_data.arn
}

output "ai_nexus_dynamodb_app_state_table_name" {
  description = "Name of the DynamoDB table for application state"
  value       = aws_dynamodb_table.ai_nexus_app_state.name
}

output "ai_nexus_dynamodb_app_state_table_arn" {
  description = "ARN of the DynamoDB table for application state"
  value       = aws_dynamodb_table.ai_nexus_app_state.arn
}

output "ai_nexus_dynamodb_sessions_table_name" {
  description = "Name of the DynamoDB table for sessions"
  value       = aws_dynamodb_table.ai_nexus_sessions.name
}

output "ai_nexus_dynamodb_files_table_name" {
  description = "Name of the DynamoDB table for file metadata"
  value       = aws_dynamodb_table.ai_nexus_files.name
}

output "ai_nexus_lambda_dynamodb_role_arn" {
  description = "ARN of the IAM role for Lambda functions accessing DynamoDB"
  value       = aws_iam_role.ai_nexus_lambda_dynamodb_role.arn
}
