# MinIO Standalone Infrastructure
# This creates a dedicated S3 infrastructure specifically for MinIO gateway mode
# Completely independent from the main AWS-DevOps CloudFormation infrastructure

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }

  # Use local state for this standalone system
  # You can migrate to S3 backend later if needed
  backend "local" {
    path = "terraform.tfstate"
  }
}

# AWS Provider Configuration
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = "MinIO-Standalone"
      ManagedBy   = "Terraform"
      Environment = var.environment
      Component   = "minio-infrastructure"
      Owner       = "DevOps"
    }
  }
}

# Random suffix for unique resource naming
resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  bucket_suffix = random_id.suffix.hex
  
  # MinIO specific buckets
  minio_buckets = {
    "minio-data" = {
      description = "Primary MinIO data storage bucket"
      versioning = true
      lifecycle = true
    }
    "minio-backups" = {
      description = "MinIO backup and replication bucket"
      versioning = true
      lifecycle = true
    }
    "minio-uploads" = {
      description = "MinIO temporary uploads bucket"
      versioning = false
      lifecycle = true
    }
    "minio-logs" = {
      description = "MinIO access and audit logs"
      versioning = false
      lifecycle = true
    }
  }

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Component   = "minio-standalone"
  }
}

# S3 Buckets for MinIO
resource "aws_s3_bucket" "minio_buckets" {
  for_each = local.minio_buckets
  
  bucket = "${local.name_prefix}-${each.key}-${local.bucket_suffix}"
  
  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-${each.key}"
    Description = each.value.description
    BucketType  = each.key
  })
}

# Versioning Configuration
resource "aws_s3_bucket_versioning" "minio_buckets" {
  for_each = { for k, v in local.minio_buckets : k => v if v.versioning }
  
  bucket = aws_s3_bucket.minio_buckets[each.key].id
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "minio_buckets" {
  for_each = local.minio_buckets
  
  bucket = aws_s3_bucket.minio_buckets[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block Public Access
resource "aws_s3_bucket_public_access_block" "minio_buckets" {
  for_each = local.minio_buckets
  
  bucket = aws_s3_bucket.minio_buckets[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle Configuration for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "minio_buckets" {
  for_each = { for k, v in local.minio_buckets : k => v if v.lifecycle }
  
  bucket = aws_s3_bucket.minio_buckets[each.key].id
  
  depends_on = [aws_s3_bucket_versioning.minio_buckets]

  rule {
    id     = "minio_lifecycle"
    status = "Enabled"

    # Apply to all objects
    filter {
      prefix = ""
    }

    # Transition to IA after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Transition to Glacier after 90 days
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # Delete incomplete multipart uploads after 7 days
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    # For versioned buckets, manage old versions
    dynamic "noncurrent_version_transition" {
      for_each = local.minio_buckets[each.key].versioning ? [1] : []
      content {
        noncurrent_days = 30
        storage_class   = "STANDARD_IA"
      }
    }

    dynamic "noncurrent_version_transition" {
      for_each = local.minio_buckets[each.key].versioning ? [1] : []
      content {
        noncurrent_days = 60
        storage_class   = "GLACIER"
      }
    }

    dynamic "noncurrent_version_expiration" {
      for_each = local.minio_buckets[each.key].versioning ? [1] : []
      content {
        noncurrent_days = 365
      }
    }
  }
}

# IAM User for MinIO
resource "aws_iam_user" "minio_user" {
  name = "${local.name_prefix}-minio-user"
  path = "/minio/"

  tags = local.common_tags
}

# IAM Access Keys for MinIO
resource "aws_iam_access_key" "minio_user" {
  user = aws_iam_user.minio_user.name
}

# IAM Policy for MinIO S3 Access
resource "aws_iam_policy" "minio_s3_policy" {
  name        = "${local.name_prefix}-minio-s3-policy"
  path        = "/minio/"
  description = "IAM policy for MinIO S3 access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:GetBucketRequestPayment",
          "s3:GetBucketVersioning",
          "s3:ListBucket",
          "s3:ListBucketVersions",
          "s3:ListBucketMultipartUploads"
        ]
        Resource = [
          for bucket in aws_s3_bucket.minio_buckets : bucket.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:ListMultipartUploadParts"
        ]
        Resource = [
          for bucket in aws_s3_bucket.minio_buckets : "${bucket.arn}/*"
        ]
      }
    ]
  })

  tags = local.common_tags
}

# Attach Policy to User
resource "aws_iam_user_policy_attachment" "minio_user_policy" {
  user       = aws_iam_user.minio_user.name
  policy_arn = aws_iam_policy.minio_s3_policy.arn
}

# CloudWatch Log Group for MinIO monitoring
resource "aws_cloudwatch_log_group" "minio_logs" {
  name              = "/aws/minio/${local.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-minio-logs"
  })
}

# CloudWatch metric configuration for S3 bucket monitoring
resource "aws_s3_bucket_metric" "minio_data_metrics" {
  bucket = aws_s3_bucket.minio_buckets["minio-data"].id
  name   = "minio-data-metrics"

  filter {
    prefix = ""
  }
}
