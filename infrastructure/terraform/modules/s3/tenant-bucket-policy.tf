# Enhanced S3 Bucket Policy for Multi-Tenant File Isolation
# This policy extends the existing bucket with tenant-aware path isolation

# Data source for the existing bucket
data "aws_s3_bucket" "app_bucket" {
  bucket = var.s3_bucket_name
}

# Enhanced bucket policy with tenant isolation
resource "aws_s3_bucket_policy" "tenant_aware_policy" {
  bucket = data.aws_s3_bucket.app_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowTenantUserPrivateAccess"
        Effect = "Allow"
        Principal = {
          Federated = var.cognito_identity_pool_arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${data.aws_s3_bucket.app_bucket.arn}/tenants/$${aws:RequestedRegion}/$${saml:tenantId}/users/$${aws:userid}/*"
        Condition = {
          StringEquals = {
            "saml:tenantId" = "$${saml:tenantId}"
          }
          "ForAllValues:StringLike" = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      {
        Sid    = "AllowTenantUserSharedRead"
        Effect = "Allow"
        Principal = {
          Federated = var.cognito_identity_pool_arn
        }
        Action = [
          "s3:GetObject"
        ]
        Resource = "${data.aws_s3_bucket.app_bucket.arn}/tenants/$${aws:RequestedRegion}/$${saml:tenantId}/shared/*"
        Condition = {
          StringEquals = {
            "saml:tenantId" = "$${saml:tenantId}"
          }
        }
      },
      {
        Sid    = "AllowTenantUserSharedWrite"
        Effect = "Allow"
        Principal = {
          Federated = var.cognito_identity_pool_arn
        }
        Action = [
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${data.aws_s3_bucket.app_bucket.arn}/tenants/$${aws:RequestedRegion}/$${saml:tenantId}/shared/$${aws:userid}/*"
        Condition = {
          StringEquals = {
            "saml:tenantId" = "$${saml:tenantId}"
          }
        }
      },
      {
        Sid    = "AllowTenantPublicRead"
        Effect = "Allow"
        Principal = {
          Federated = var.cognito_identity_pool_arn
        }
        Action = [
          "s3:GetObject"
        ]
        Resource = "${data.aws_s3_bucket.app_bucket.arn}/tenants/$${aws:RequestedRegion}/$${saml:tenantId}/public/*"
        Condition = {
          StringEquals = {
            "saml:tenantId" = "$${saml:tenantId}"
          }
        }
      },
      {
        Sid    = "AllowTenantAdminPublicWrite"
        Effect = "Allow"
        Principal = {
          Federated = var.cognito_identity_pool_arn
        }
        Action = [
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${data.aws_s3_bucket.app_bucket.arn}/tenants/$${aws:RequestedRegion}/$${saml:tenantId}/public/*"
        Condition = {
          StringEquals = {
            "saml:tenantId" = "$${saml:tenantId}"
            "saml:role" = ["admin", "owner"]
          }
        }
      },
      {
        Sid    = "AllowSystemTemplatesRead"
        Effect = "Allow"
        Principal = {
          Federated = var.cognito_identity_pool_arn
        }
        Action = [
          "s3:GetObject"
        ]
        Resource = "${data.aws_s3_bucket.app_bucket.arn}/system/templates/*"
        Condition = {
          StringLike = {
            "aws:userid" = "*"
          }
        }
      },
      {
        Sid    = "AllowTempFileAccess"
        Effect = "Allow"
        Principal = {
          Federated = var.cognito_identity_pool_arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${data.aws_s3_bucket.app_bucket.arn}/temp/$${aws:userid}/*"
        Condition = {
          StringLike = {
            "aws:userid" = "*"
          }
          "DateGreaterThan" = {
            "aws:CurrentTime" = "1970-01-01T00:00:00Z"
          }
        }
      },
      {
        Sid    = "DenyAccessToOtherTenants"
        Effect = "Deny"
        Principal = {
          Federated = var.cognito_identity_pool_arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${data.aws_s3_bucket.app_bucket.arn}/tenants/*"
        Condition = {
          StringNotEquals = {
            "s3:ExistingObjectTag/tenantId" = "$${saml:tenantId}"
          }
          StringLike = {
            "s3:prefix" = "tenants/*"
          }
        }
      },
      {
        Sid    = "RequireSSLRequestsOnly"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          data.aws_s3_bucket.app_bucket.arn,
          "${data.aws_s3_bucket.app_bucket.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "RequireEncryptionInTransit"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:PutObject"
        Resource = "${data.aws_s3_bucket.app_bucket.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "AES256"
          }
        }
      },
      # Backward compatibility for existing user files (migration period)
      {
        Sid    = "AllowLegacyUserAccess"
        Effect = "Allow"
        Principal = {
          Federated = var.cognito_identity_pool_arn
        }
        Action = [
          "s3:GetObject"
        ]
        Resource = "${data.aws_s3_bucket.app_bucket.arn}/private/$${aws:userid}/*"
        Condition = {
          StringLike = {
            "aws:userid" = "*"
          }
          "DateLessThan" = {
            "aws:CurrentTime" = var.legacy_cutoff_date
          }
        }
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.app_bucket_pab
  ]
}

# Public access block (maintain security)
resource "aws_s3_bucket_public_access_block" "app_bucket_pab" {
  bucket = data.aws_s3_bucket.app_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket notification for tenant file events
resource "aws_s3_bucket_notification" "tenant_file_events" {
  count  = var.enable_file_event_notifications ? 1 : 0
  bucket = data.aws_s3_bucket.app_bucket.id

  lambda_function {
    lambda_function_arn = var.tenant_file_processor_lambda_arn
    events              = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
    filter_prefix       = "tenants/"
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}

# Lambda permission for S3 to invoke file processor
resource "aws_lambda_permission" "allow_s3_invoke" {
  count         = var.enable_file_event_notifications ? 1 : 0
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = var.tenant_file_processor_lambda_name
  principal     = "s3.amazonaws.com"
  source_arn    = data.aws_s3_bucket.app_bucket.arn
}

# CloudWatch Metrics for tenant file access
resource "aws_cloudwatch_log_metric_filter" "tenant_file_access" {
  count          = var.enable_access_logging ? 1 : 0
  name           = "TenantFileAccess"
  log_group_name = var.s3_access_log_group_name
  pattern        = "[timestamp, request_id, requester, bucket, key = \"tenants/*\", operation, result_code != 4*, ...]"

  metric_transformation {
    name      = "TenantFileAccessCount"
    namespace = "AI-Nexus/TenantMetrics"
    value     = "1"
    
    default_value = 0
    
    # Extract tenant ID from the S3 key path
    dimensions = {
      TenantId = "$${key}"
    }
  }
}

# CloudWatch Alarm for suspicious cross-tenant access attempts
resource "aws_cloudwatch_metric_alarm" "cross_tenant_access_attempts" {
  count               = var.enable_security_monitoring ? 1 : 0
  alarm_name          = "${var.project_prefix}-cross-tenant-access-attempts-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TenantAccessDenied"
  namespace           = "AI-Nexus/Security"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors cross-tenant access attempts"
  alarm_actions       = [var.security_sns_topic_arn]

  tags = var.default_tags
}

# S3 Intelligent Tiering for cost optimization
resource "aws_s3_bucket_intelligent_tiering_configuration" "tenant_files" {
  count  = var.enable_intelligent_tiering ? 1 : 0
  bucket = data.aws_s3_bucket.app_bucket.id
  name   = "TenantFilesIntelligentTiering"

  filter {
    prefix = "tenants/"
  }

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }

  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }

  optional_fields = ["BucketKeyStatus", "RequestPayer"]
}

# Lifecycle configuration for tenant files
resource "aws_s3_bucket_lifecycle_configuration" "tenant_lifecycle" {
  count  = var.enable_lifecycle_rules ? 1 : 0
  bucket = data.aws_s3_bucket.app_bucket.id

  rule {
    id     = "tenant_files_lifecycle"
    status = "Enabled"

    filter {
      prefix = "tenants/"
    }

    # Move to IA after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Move to Glacier after 90 days
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # Move to Deep Archive after 365 days
    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    # Clean up temp files after 1 day
    expiration {
      days = 1
      expired_object_delete_marker = true
    }
  }

  rule {
    id     = "temp_files_cleanup"
    status = "Enabled"

    filter {
      prefix = "temp/"
    }

    expiration {
      days = 1
    }
  }

  rule {
    id     = "multipart_upload_cleanup"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Variables
variable "s3_bucket_name" {
  description = "Name of the existing S3 bucket"
  type        = string
}

variable "cognito_identity_pool_arn" {
  description = "ARN of the Cognito Identity Pool"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "legacy_cutoff_date" {
  description = "ISO 8601 date after which legacy paths are no longer accessible"
  type        = string
  default     = "2024-12-31T23:59:59Z"
}

variable "enable_file_event_notifications" {
  description = "Enable S3 event notifications for Lambda processing"
  type        = bool
  default     = true
}

variable "tenant_file_processor_lambda_arn" {
  description = "ARN of the Lambda function to process tenant file events"
  type        = string
  default     = ""
}

variable "tenant_file_processor_lambda_name" {
  description = "Name of the Lambda function to process tenant file events"
  type        = string
  default     = ""
}

variable "enable_access_logging" {
  description = "Enable S3 access logging and metrics"
  type        = bool
  default     = true
}

variable "s3_access_log_group_name" {
  description = "CloudWatch log group for S3 access logs"
  type        = string
  default     = "/aws/s3/access-logs"
}

variable "enable_security_monitoring" {
  description = "Enable security monitoring and alerts"
  type        = bool
  default     = true
}

variable "security_sns_topic_arn" {
  description = "SNS topic ARN for security alerts"
  type        = string
  default     = ""
}

variable "enable_intelligent_tiering" {
  description = "Enable S3 Intelligent Tiering for cost optimization"
  type        = bool
  default     = true
}

variable "enable_lifecycle_rules" {
  description = "Enable S3 lifecycle rules for cost optimization"
  type        = bool
  default     = true
}

variable "project_prefix" {
  description = "Project prefix for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Outputs
output "bucket_policy_id" {
  description = "ID of the S3 bucket policy"
  value       = aws_s3_bucket_policy.tenant_aware_policy.id
}

output "tenant_file_structure" {
  description = "Tenant file structure information"
  value = {
    user_private_path = "tenants/{tenantId}/users/{userId}/"
    tenant_shared_path = "tenants/{tenantId}/shared/"
    tenant_public_path = "tenants/{tenantId}/public/"
    system_templates_path = "system/templates/"
    temp_files_path = "temp/{userId}/"
  }
}
