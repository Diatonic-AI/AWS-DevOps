# S3 Module - Enterprise-grade S3 Infrastructure
# This module creates a comprehensive S3 setup with multiple buckets for different purposes,
# security best practices, lifecycle management, and cross-region replication

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.replica]
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# Local values for consistent naming and configuration
locals {
  region     = var.region != null ? var.region : data.aws_region.current.name
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  # Bucket definitions
  bucket_types = {
    application   = var.create_application_bucket
    backup        = var.create_backup_bucket
    logs          = var.create_logs_bucket
    static-assets = var.create_static_assets_bucket
    compliance    = var.create_compliance_bucket
    data-lake     = var.create_data_lake_bucket
  }

  # Create bucket names with consistent naming pattern
  bucket_names = {
    for type, create in local.bucket_types :
    type => "${var.name_prefix}-${type}-${var.environment}-${random_string.bucket_suffix.result}"
    if create
  }

  # Common tags for all resources
  common_tags = merge(var.tags, {
    Module      = "s3"
    Environment = var.environment
    ManagedBy   = "Terraform"
  })

  # Replication destination bucket names
  replication_bucket_names = var.enable_cross_region_replication ? {
    for type in var.replicate_buckets :
    type => "${var.name_prefix}-${type}-replica-${var.environment}-${random_string.bucket_suffix.result}"
    if lookup(local.bucket_types, type, false)
  } : {}
}

# Random string for unique bucket naming
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# KMS Key for S3 encryption (if not provided)
resource "aws_kms_key" "s3_key" {
  count = var.enable_server_side_encryption && var.kms_key_id == null ? 1 : 0

  description             = "S3 encryption key for ${var.name_prefix}-${var.environment}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-s3-key-${var.environment}"
    Type = "kms_key"
  })
}

resource "aws_kms_alias" "s3_key_alias" {
  count = var.enable_server_side_encryption && var.kms_key_id == null ? 1 : 0

  name          = "alias/${var.name_prefix}-s3-${var.environment}"
  target_key_id = aws_kms_key.s3_key[0].key_id
}

# IAM Role for Cross-Region Replication
resource "aws_iam_role" "replication_role" {
  count = var.enable_cross_region_replication ? 1 : 0

  name = "${var.name_prefix}-s3-replication-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "replication_policy" {
  count = var.enable_cross_region_replication ? 1 : 0

  name = "${var.name_prefix}-s3-replication-policy-${var.environment}"
  role = aws_iam_role.replication_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl"
        ]
        Resource = [for name in values(local.bucket_names) : "arn:${local.partition}:s3:::${name}/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [for name in values(local.bucket_names) : "arn:${local.partition}:s3:::${name}"]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete"
        ]
        Resource = [for name in values(local.replication_bucket_names) : "arn:${local.partition}:s3:::${name}/*"]
      }
    ]
  })
}

# Primary S3 Buckets
resource "aws_s3_bucket" "main" {
  for_each = local.bucket_names

  bucket = each.value

  tags = merge(local.common_tags, {
    Name       = each.value
    Type       = each.key
    BucketType = each.key
  }, lookup(var.additional_bucket_tags, each.key, {}))
}

# Replication destination buckets (in different region)
resource "aws_s3_bucket" "replica" {
  for_each = local.replication_bucket_names

  provider = aws.replica
  bucket   = each.value

  tags = merge(local.common_tags, {
    Name       = each.value
    Type       = each.key
    BucketType = "${each.key}-replica"
    Purpose    = "replication"
  })
}

# Bucket versioning configuration
resource "aws_s3_bucket_versioning" "main" {
  for_each = local.bucket_names

  bucket = aws_s3_bucket.main[each.key].id

  versioning_configuration {
    status     = var.enable_versioning ? "Enabled" : "Disabled"
    mfa_delete = var.enable_mfa_delete && var.enable_versioning ? "Enabled" : "Disabled"
  }
}

resource "aws_s3_bucket_versioning" "replica" {
  for_each = local.replication_bucket_names

  provider = aws.replica
  bucket   = aws_s3_bucket.replica[each.key].id

  versioning_configuration {
    status = "Enabled" # Required for replication
  }
}

# Server-side encryption configuration
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  for_each = var.enable_server_side_encryption ? local.bucket_names : {}

  bucket = aws_s3_bucket.main[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_id != null ? var.kms_key_id : (
        length(aws_kms_key.s3_key) > 0 ? aws_kms_key.s3_key[0].arn : null
      )
      sse_algorithm = var.kms_key_id != null || length(aws_kms_key.s3_key) > 0 ? "aws:kms" : "AES256"
    }
    bucket_key_enabled = var.kms_key_id != null || length(aws_kms_key.s3_key) > 0
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "replica" {
  for_each = var.enable_cross_region_replication && var.enable_server_side_encryption ? local.replication_bucket_names : {}

  provider = aws.replica
  bucket   = aws_s3_bucket.replica[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # Use default encryption for replica buckets
    }
  }
}

# Public access block (security best practice)
resource "aws_s3_bucket_public_access_block" "main" {
  for_each = local.bucket_names

  bucket = aws_s3_bucket.main[each.key].id

  block_public_acls       = !contains(var.public_read_buckets, each.key)
  block_public_policy     = !contains(var.public_read_buckets, each.key)
  ignore_public_acls      = !contains(var.public_read_buckets, each.key)
  restrict_public_buckets = !contains(var.public_read_buckets, each.key)
}

resource "aws_s3_bucket_public_access_block" "replica" {
  for_each = local.replication_bucket_names

  provider = aws.replica
  bucket   = aws_s3_bucket.replica[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket policies
resource "aws_s3_bucket_policy" "main" {
  for_each = local.bucket_names

  bucket = aws_s3_bucket.main[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      # Deny insecure connections
      {
        Sid       = "DenyInsecureConnections"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          "arn:${local.partition}:s3:::${each.value}",
          "arn:${local.partition}:s3:::${each.value}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
      ], contains(var.public_read_buckets, each.key) ? [
      # Allow public read for specified buckets (e.g., static assets)
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "arn:${local.partition}:s3:::${each.value}/*"
      }
    ] : [])
  })

  depends_on = [aws_s3_bucket_public_access_block.main]
}

# Lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "main" {
  for_each = {
    for k, v in local.bucket_names : k => v
    if lookup(var.lifecycle_rules, k, {
      enabled                            = false
      transitions                        = []
      expiration_days                    = null
      noncurrent_version_expiration_days = null
    }).enabled
  }

  bucket = aws_s3_bucket.main[each.key].id

  rule {
    id     = "lifecycle-rule"
    status = "Enabled"

    filter {
      prefix = "" # Apply to all objects
    }

    # Intelligent tiering - only when no custom transitions exist
    dynamic "transition" {
      for_each = var.enable_intelligent_tiering && length(lookup(var.lifecycle_rules, each.key, {
        enabled                            = false
        transitions                        = []
        expiration_days                    = null
        noncurrent_version_expiration_days = null
      }).transitions) == 0 ? [1] : []
      content {
        days          = 0
        storage_class = "INTELLIGENT_TIERING"
      }
    }

    # Standard transitions
    dynamic "transition" {
      for_each = contains(keys(var.lifecycle_rules), each.key) ? var.lifecycle_rules[each.key].transitions : []
      content {
        days          = transition.value.days
        storage_class = transition.value.storage_class
      }
    }

    # Current version expiration
    dynamic "expiration" {
      for_each = lookup(var.lifecycle_rules, each.key, {
        enabled                            = false
        transitions                        = []
        expiration_days                    = null
        noncurrent_version_expiration_days = null
      }).expiration_days != null ? [1] : []
      content {
        days = lookup(var.lifecycle_rules, each.key, {
          enabled                            = false
          transitions                        = []
          expiration_days                    = null
          noncurrent_version_expiration_days = null
        }).expiration_days
      }
    }

    # Non-current version expiration
    dynamic "noncurrent_version_expiration" {
      for_each = lookup(var.lifecycle_rules, each.key, {
        enabled                            = false
        transitions                        = []
        expiration_days                    = null
        noncurrent_version_expiration_days = null
      }).noncurrent_version_expiration_days != null ? [1] : []
      content {
        noncurrent_days = lookup(var.lifecycle_rules, each.key, {
          enabled                            = false
          transitions                        = []
          expiration_days                    = null
          noncurrent_version_expiration_days = null
        }).noncurrent_version_expiration_days
      }
    }

    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Cross-region replication configuration
resource "aws_s3_bucket_replication_configuration" "main" {
  for_each = var.enable_cross_region_replication ? {
    for k, v in local.bucket_names : k => v
    if contains(var.replicate_buckets, k)
  } : {}

  role   = aws_iam_role.replication_role[0].arn
  bucket = aws_s3_bucket.main[each.key].id

  rule {
    id     = "ReplicateAll"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.replica[each.key].arn
      storage_class = "STANDARD_IA"

      # Replica encryption
      encryption_configuration {
        replica_kms_key_id = "alias/aws/s3"
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.main, aws_s3_bucket_versioning.replica]
}

# Access logging configuration
resource "aws_s3_bucket_logging" "main" {
  for_each = var.enable_access_logging && contains(keys(local.bucket_names), "logs") ? {
    for k, v in local.bucket_names : k => v
    if k != "logs" # Don't log the logs bucket to itself
  } : {}

  bucket = aws_s3_bucket.main[each.key].id

  target_bucket = aws_s3_bucket.main["logs"].id
  target_prefix = "access-logs/${each.key}/"
}

# Request payment configuration
resource "aws_s3_bucket_request_payment_configuration" "main" {
  for_each = var.request_payer == "Requester" ? local.bucket_names : {}

  bucket = aws_s3_bucket.main[each.key].id
  payer  = var.request_payer
}

# CORS configuration for static assets
resource "aws_s3_bucket_cors_configuration" "static_assets" {
  count = length(var.cors_rules) > 0 && contains(keys(local.bucket_names), "static-assets") ? 1 : 0

  bucket = aws_s3_bucket.main["static-assets"].id

  dynamic "cors_rule" {
    for_each = var.cors_rules
    content {
      allowed_headers = cors_rule.value.allowed_headers
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      expose_headers  = cors_rule.value.expose_headers
      max_age_seconds = cors_rule.value.max_age_seconds
    }
  }
}

# Website configuration for static assets
resource "aws_s3_bucket_website_configuration" "static_assets" {
  count = var.enable_static_website && contains(keys(local.bucket_names), "static-assets") ? 1 : 0

  bucket = aws_s3_bucket.main["static-assets"].id

  index_document {
    suffix = var.website_index_document
  }

  error_document {
    key = var.website_error_document
  }
}

# CloudWatch metrics configuration
resource "aws_s3_bucket_metric" "main" {
  for_each = var.enable_metrics ? local.bucket_names : {}

  bucket = aws_s3_bucket.main[each.key].id
  name   = "EntireBucket"
}

# Inventory configuration (for large buckets in production)
resource "aws_s3_bucket_inventory" "main" {
  for_each = var.enable_inventory && contains(keys(local.bucket_names), "logs") ? {
    for k, v in local.bucket_names : k => v
    if k != "logs"
  } : {}

  bucket = aws_s3_bucket.main[each.key].id
  name   = "EntireBucketDaily"

  included_object_versions = "All"

  schedule {
    frequency = "Daily"
  }

  destination {
    bucket {
      format     = "CSV"
      bucket_arn = aws_s3_bucket.main["logs"].arn
      prefix     = "inventory/${each.key}/"
    }
  }

  optional_fields = [
    "Size",
    "LastModifiedDate",
    "StorageClass",
    "ETag",
    "IsMultipartUploaded",
    "ReplicationStatus"
  ]
}

# Event notifications
resource "aws_s3_bucket_notification" "main" {
  for_each = var.enable_event_notifications ? local.bucket_names : {}

  bucket = aws_s3_bucket.main[each.key].id

  dynamic "lambda_function" {
    for_each = var.notification_lambda_arn != null ? [1] : []
    content {
      lambda_function_arn = var.notification_lambda_arn
      events              = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
    }
  }

  dynamic "topic" {
    for_each = var.notification_sns_topic_arn != null ? [1] : []
    content {
      topic_arn = var.notification_sns_topic_arn
      events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
    }
  }
}
