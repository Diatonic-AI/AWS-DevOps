# Backend Setup Configuration
# This creates the S3 bucket and DynamoDB table for remote state management
# Run this FIRST before applying the main configuration

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "AWS-DevOps"
      ManagedBy = "Terraform-Backend-Setup"
      Purpose   = "State Management"
    }
  }
}

variable "aws_region" {
  description = "AWS region for backend resources"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "aws-devops"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# Random suffix for unique bucket naming
resource "random_string" "backend_suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 Bucket for Terraform State
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-terraform-state-unified-${random_string.backend_suffix.result}"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-terraform-state"
    Environment = "global"
    Purpose     = "Terraform State Storage"
  }
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Server-side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Policy for State Access
resource "aws_s3_bucket_policy" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureConnections"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid       = "DenyDirectObjectAccess"
        Effect    = "Deny"
        Principal = "*"
        Action = [
          "s3:DeleteObject",
          "s3:DeleteObjectVersion"
        ]
        Resource = "${aws_s3_bucket.terraform_state.arn}/*"
        Condition = {
          StringNotEquals = {
            "aws:userid" = [
              "AIDACKCEVSQ6C2EXAMPLE", # Replace with actual User ID
              "AROLECKCEVSQ6C2EXAMPLE" # Replace with actual Role ID
            ]
          }
        }
      }
    ]
  })
}

# S3 Bucket Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "state_lifecycle"
    status = "Enabled"

    # Keep non-current versions for 90 days
    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    # Move old versions to IA after 30 days
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    # Delete incomplete multipart uploads after 7 days
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# DynamoDB Table for State Locking
resource "aws_dynamodb_table" "terraform_state_lock" {
  name         = "${var.project_name}-terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-terraform-state-lock"
    Environment = "global"
    Purpose     = "Terraform State Locking"
  }
}

# CloudWatch Log Group for Backend Operations
resource "aws_cloudwatch_log_group" "backend_operations" {
  name              = "/aws/terraform/${var.project_name}/backend"
  retention_in_days = 30

  tags = {
    Name        = "${var.project_name}-backend-logs"
    Environment = "global"
  }
}

# Outputs for backend configuration
output "s3_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_state_lock.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_state_lock.arn
}

output "backend_configuration" {
  description = "Backend configuration block for main terraform files"
  value = {
    bucket               = aws_s3_bucket.terraform_state.id
    key                  = "unified/terraform.tfstate"
    region               = local.region
    dynamodb_table       = aws_dynamodb_table.terraform_state_lock.name
    encrypt              = true
    workspace_key_prefix = "workspaces"
  }
}

# Create backend configuration template
resource "local_file" "backend_config_template" {
  filename = "${path.module}/../backend-config.txt"
  content  = <<-EOT
# Add this backend configuration to your main.tf file:

terraform {
  backend "s3" {
    bucket         = "${aws_s3_bucket.terraform_state.id}"
    key            = "unified/terraform.tfstate"
    region         = "${local.region}"
    dynamodb_table = "${aws_dynamodb_table.terraform_state_lock.name}"
    encrypt        = true
    workspace_key_prefix = "workspaces"
  }
}

# Workspace Commands:
# terraform workspace new dev
# terraform workspace new staging  
# terraform workspace new prod
# terraform workspace new ai-nexus
# terraform workspace new minio

# State files will be stored at:
# s3://${aws_s3_bucket.terraform_state.id}/workspaces/dev/unified/terraform.tfstate
# s3://${aws_s3_bucket.terraform_state.id}/workspaces/staging/unified/terraform.tfstate
# s3://${aws_s3_bucket.terraform_state.id}/workspaces/prod/unified/terraform.tfstate
# etc.
EOT
}
