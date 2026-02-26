# MMP Toledo DynamoDB to Supabase Sync - Root Configuration
#
# This deployment creates the most cost-optimized architecture for syncing
# DynamoDB tables to Supabase in real-time using DynamoDB Streams and Lambda.
#
# Architecture:
# ┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────────────┐
# │  DynamoDB       │    │  Lambda (ARM64)  │    │  Supabase Edge Function     │
# │  Tables         │───▶│  128MB Memory    │───▶│  mmp-toledo-sync            │
# │  (Streams)      │    │  Node.js 20.x    │    │                             │
# └─────────────────┘    └──────────────────┘    └─────────────────────────────┘
#                               │
#                               ▼
#                        ┌──────────────────┐
#                        │  SQS DLQ         │
#                        │  (Failed msgs)   │
#                        └──────────────────┘
#
# Cost Breakdown (Monthly):
# - DynamoDB Streams: $0.00 (included with DynamoDB)
# - Lambda ARM64:     $0.00 (within free tier for low volume)
# - Secrets Manager:  $0.40 (1 secret)
# - CloudWatch Logs:  $0.00-$0.50 (depends on volume)
# - SQS DLQ:          $0.00 (within free tier)
# Total:              ~$0.40-$1.00/month
#
# Deployment:
#   cd infrastructure/terraform/mmp-toledo-sync
#   terraform init
#   terraform plan -out=tfplan
#   terraform apply tfplan

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # S3 Backend Configuration (uncomment for production)
  # backend "s3" {
  #   bucket         = "aws-devops-terraform-state-313476888312-us-east-2"
  #   key            = "mmp-toledo-sync/terraform.tfstate"
  #   region         = "us-east-2"
  #   dynamodb_table = "aws-devops-terraform-state-lock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = "MMP-Toledo"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Component   = "dynamodb-supabase-sync"
      CostCenter  = "mmp-toledo"
    }
  }
}

# ============================================================================
# DATA SOURCES - Query existing DynamoDB tables
# ============================================================================

# Get account ID for ARN construction
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Reference existing DynamoDB tables (looked up dynamically)
# These are optional - only queried if sync is enabled

data "aws_dynamodb_table" "mmp_toledo_leads" {
  count = var.enable_leads_table_sync ? 1 : 0
  name  = var.leads_table_name
}

data "aws_dynamodb_table" "mmp_toledo_otp" {
  count = var.enable_otp_table_sync ? 1 : 0
  name  = var.otp_table_name
}

data "aws_dynamodb_table" "toledo_dashboard" {
  count = var.enable_dashboard_table_sync ? 1 : 0
  name  = var.dashboard_table_name
}

# ============================================================================
# LOCAL VALUES
# ============================================================================

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  # Build list of table ARNs dynamically from data sources
  dynamodb_table_arns = compact([
    var.enable_leads_table_sync ? data.aws_dynamodb_table.mmp_toledo_leads[0].arn : "",
    var.enable_otp_table_sync ? data.aws_dynamodb_table.mmp_toledo_otp[0].arn : "",
    var.enable_dashboard_table_sync ? data.aws_dynamodb_table.toledo_dashboard[0].arn : "",
  ])

  # Build list of stream ARNs dynamically from data sources
  dynamodb_stream_arns = compact([
    var.enable_leads_table_sync ? data.aws_dynamodb_table.mmp_toledo_leads[0].stream_arn : "",
    var.enable_otp_table_sync ? data.aws_dynamodb_table.mmp_toledo_otp[0].stream_arn : "",
    var.enable_dashboard_table_sync ? data.aws_dynamodb_table.toledo_dashboard[0].stream_arn : "",
  ])

  # Build streams map for event source mappings
  dynamodb_streams = merge(
    var.enable_leads_table_sync ? {
      "mmp-toledo-leads" = {
        stream_arn     = data.aws_dynamodb_table.mmp_toledo_leads[0].stream_arn
        filter_pattern = null # Sync all events
      }
    } : {},
    var.enable_otp_table_sync ? {
      "mmp-toledo-otp" = {
        stream_arn     = data.aws_dynamodb_table.mmp_toledo_otp[0].stream_arn
        filter_pattern = null
      }
    } : {},
    var.enable_dashboard_table_sync ? {
      "toledo-dashboard" = {
        stream_arn     = data.aws_dynamodb_table.toledo_dashboard[0].stream_arn
        filter_pattern = null
      }
    } : {}
  )
}

# ============================================================================
# MMP TOLEDO SYNC MODULE
# ============================================================================

module "mmp_toledo_sync" {
  source = "../modules/mmp-toledo-sync"

  # Required configuration
  project_prefix = var.project_name
  environment    = var.environment
  aws_region     = var.aws_region

  # Supabase configuration
  supabase_url              = var.supabase_url
  supabase_anon_key         = var.supabase_anon_key
  supabase_service_role_key = var.supabase_service_role_key
  supabase_webhook_url      = var.supabase_webhook_url

  # DynamoDB configuration
  dynamodb_table_arns        = local.dynamodb_table_arns
  dynamodb_table_stream_arns = local.dynamodb_stream_arns
  dynamodb_streams           = local.dynamodb_streams

  # Lambda configuration (cost optimized defaults)
  lambda_memory_size             = var.lambda_memory_size
  lambda_timeout                 = var.lambda_timeout
  reserved_concurrent_executions = var.reserved_concurrent_executions

  # Batch processing
  batch_size              = var.batch_size
  batching_window_seconds = var.batching_window_seconds

  # Retry configuration
  max_retries        = var.max_retries
  retry_delay_ms     = var.retry_delay_ms
  stream_max_retries = var.stream_max_retries

  # Logging
  log_retention_days = var.log_retention_days

  # Monitoring (disabled by default for cost optimization)
  enable_monitoring   = var.enable_monitoring
  alarm_sns_topic_arn = var.alarm_sns_topic_arn

  # Tags
  default_tags = var.default_tags
}

# ============================================================================
# OPTIONAL: CREATE DYNAMODB TABLES IF THEY DON'T EXIST
# ============================================================================

# Uncomment if you need to create the DynamoDB tables

# resource "aws_dynamodb_table" "mmp_toledo_leads" {
#   count = var.create_dynamodb_tables ? 1 : 0
#
#   name           = var.leads_table_name
#   billing_mode   = "PAY_PER_REQUEST"  # Most cost-effective for variable workloads
#   hash_key       = "lead_id"
#
#   attribute {
#     name = "lead_id"
#     type = "S"
#   }
#
#   stream_enabled   = true
#   stream_view_type = "NEW_AND_OLD_IMAGES"
#
#   point_in_time_recovery {
#     enabled = var.environment == "prod"
#   }
#
#   tags = merge(var.default_tags, {
#     Name = "MMP Toledo Leads Table"
#   })
# }

# resource "aws_dynamodb_table" "mmp_toledo_otp" {
#   count = var.create_dynamodb_tables ? 1 : 0
#
#   name           = var.otp_table_name
#   billing_mode   = "PAY_PER_REQUEST"
#   hash_key       = "otp_id"
#
#   attribute {
#     name = "otp_id"
#     type = "S"
#   }
#
#   stream_enabled   = true
#   stream_view_type = "NEW_AND_OLD_IMAGES"
#
#   ttl {
#     attribute_name = "expires_at"
#     enabled        = true
#   }
#
#   tags = merge(var.default_tags, {
#     Name = "MMP Toledo OTP Table"
#   })
# }
