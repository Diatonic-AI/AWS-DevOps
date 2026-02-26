# Multi-Tenant DynamoDB Tables for AI Nexus Workbench
# This module creates the enhanced DynamoDB tables to support organization-level multi-tenancy

# Organizations/Tenants Table
resource "aws_dynamodb_table" "organizations" {
  name           = "${var.project_prefix}-organizations-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "tenantId"
  stream_enabled = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "tenantId"
    type = "S"
  }

  attribute {
    name = "domain"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  # GSI for domain-based tenant lookup (for subdomain routing)
  global_secondary_index {
    name     = "DomainIndex"
    hash_key = "domain"
    projection_type = "ALL"
  }

  # GSI for querying by status (active, suspended, trial)
  global_secondary_index {
    name     = "StatusIndex"
    hash_key = "status"
    projection_type = "ALL"
  }

  tags = merge(var.default_tags, {
    Name = "Organizations Table"
    Purpose = "Multi-tenant organization management"
  })

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_id = var.dynamodb_kms_key_id
  }

  lifecycle {
    prevent_destroy = true
  }
}

# User-Organization Mapping Table
resource "aws_dynamodb_table" "user_organizations" {
  name           = "${var.project_prefix}-user-orgs-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "userId"
  range_key      = "tenantId"
  stream_enabled = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "tenantId"
    type = "S"
  }

  attribute {
    name = "role"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  # GSI for tenant-to-users lookup (list all users in a tenant)
  global_secondary_index {
    name     = "TenantUsersIndex"
    hash_key = "tenantId"
    range_key = "status"
    projection_type = "ALL"
  }

  # GSI for role-based queries (find all admins, etc.)
  global_secondary_index {
    name     = "UserRoleIndex"
    hash_key = "tenantId"
    range_key = "role"
    projection_type = "ALL"
  }

  tags = merge(var.default_tags, {
    Name = "User Organizations Table"
    Purpose = "User-tenant membership and roles"
  })

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_id = var.dynamodb_kms_key_id
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Enhanced User Data Table (migration of existing table)
resource "aws_dynamodb_table" "user_data_enhanced" {
  name           = "${var.project_prefix}-user-data-v2-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "userId"
  range_key      = "dataKey"  # Composite: tenantId#dataType#id
  stream_enabled = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "dataKey"
    type = "S"
  }

  attribute {
    name = "tenantId"
    type = "S"
  }

  attribute {
    name = "dataType"
    type = "S"
  }

  # GSI for tenant-wide data queries
  global_secondary_index {
    name     = "TenantDataIndex"
    hash_key = "tenantId"
    range_key = "dataType"
    projection_type = "ALL"
  }

  # GSI for efficient data type queries within tenant
  global_secondary_index {
    name     = "TenantDataTypeIndex"
    hash_key = "tenantId"
    range_key = "dataKey"
    projection_type = "ALL"
  }

  tags = merge(var.default_tags, {
    Name = "Enhanced User Data Table"
    Purpose = "Tenant-aware user data storage"
  })

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_id = var.dynamodb_kms_key_id
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Tenant Usage Metrics Table
resource "aws_dynamodb_table" "tenant_usage" {
  name           = "${var.project_prefix}-tenant-usage-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "tenantId"
  range_key      = "metricKey"  # Format: YYYY-MM-DD#metric_type

  attribute {
    name = "tenantId"
    type = "S"
  }

  attribute {
    name = "metricKey"
    type = "S"
  }

  attribute {
    name = "metricType"
    type = "S"
  }

  # GSI for querying specific metric types across tenants
  global_secondary_index {
    name     = "MetricTypeIndex"
    hash_key = "metricType"
    range_key = "metricKey"
    projection_type = "ALL"
  }

  # TTL for automatic cleanup of old metrics (keep 13 months)
  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }

  tags = merge(var.default_tags, {
    Name = "Tenant Usage Metrics Table"
    Purpose = "Track per-tenant usage and billing metrics"
  })

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_id = var.dynamodb_kms_key_id
  }
}

# Tenant Invitations Table (for pending user invitations)
resource "aws_dynamodb_table" "tenant_invitations" {
  name           = "${var.project_prefix}-tenant-invitations-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "invitationId"

  attribute {
    name = "invitationId"
    type = "S"
  }

  attribute {
    name = "tenantId"
    type = "S"
  }

  attribute {
    name = "email"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  # GSI for tenant invitation management
  global_secondary_index {
    name     = "TenantInvitationsIndex"
    hash_key = "tenantId"
    range_key = "status"
    projection_type = "ALL"
  }

  # GSI for email-based invitation lookup
  global_secondary_index {
    name     = "EmailInvitationsIndex"
    hash_key = "email"
    range_key = "status"
    projection_type = "ALL"
  }

  # TTL for automatic cleanup of expired invitations (30 days)
  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }

  tags = merge(var.default_tags, {
    Name = "Tenant Invitations Table"
    Purpose = "Manage pending user invitations to organizations"
  })

  server_side_encryption {
    enabled     = true
    kms_key_id = var.dynamodb_kms_key_id
  }
}

# CloudWatch Alarms for tenant tables
resource "aws_cloudwatch_metric_alarm" "organizations_throttles" {
  alarm_name          = "${var.project_prefix}-organizations-throttles-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UserErrors"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors organizations table throttles"
  alarm_actions       = [var.sns_alarm_topic_arn]

  dimensions = {
    TableName = aws_dynamodb_table.organizations.name
  }

  tags = var.default_tags
}

resource "aws_cloudwatch_metric_alarm" "user_orgs_throttles" {
  alarm_name          = "${var.project_prefix}-user-orgs-throttles-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UserErrors"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors user-organizations table throttles"
  alarm_actions       = [var.sns_alarm_topic_arn]

  dimensions = {
    TableName = aws_dynamodb_table.user_organizations.name
  }

  tags = var.default_tags
}

# Outputs
output "organizations_table_name" {
  description = "Name of the organizations DynamoDB table"
  value       = aws_dynamodb_table.organizations.name
}

output "organizations_table_arn" {
  description = "ARN of the organizations DynamoDB table"
  value       = aws_dynamodb_table.organizations.arn
}

output "user_organizations_table_name" {
  description = "Name of the user-organizations DynamoDB table"
  value       = aws_dynamodb_table.user_organizations.name
}

output "user_organizations_table_arn" {
  description = "ARN of the user-organizations DynamoDB table"
  value       = aws_dynamodb_table.user_organizations.arn
}

output "user_data_enhanced_table_name" {
  description = "Name of the enhanced user data DynamoDB table"
  value       = aws_dynamodb_table.user_data_enhanced.name
}

output "tenant_usage_table_name" {
  description = "Name of the tenant usage metrics DynamoDB table"
  value       = aws_dynamodb_table.tenant_usage.name
}

output "tenant_invitations_table_name" {
  description = "Name of the tenant invitations DynamoDB table"
  value       = aws_dynamodb_table.tenant_invitations.name
}
