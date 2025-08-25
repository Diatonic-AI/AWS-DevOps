# Core S3 Infrastructure Configuration
# This file creates enterprise-grade S3 infrastructure integrated with our VPC

# Local values for S3 configuration
locals {
  s3_name_prefix = "${var.project_name}-${var.environment}"

  # Environment-specific S3 configuration
  s3_config = {
    development = {
      enable_cross_region_replication = false
      enable_mfa_delete               = false
      enable_inventory                = false
      enable_static_website           = false
      cors_origins                    = ["http://localhost:3000", "http://localhost:8080"]
      enable_event_notifications      = false
      create_data_lake_bucket         = false
    }
    staging = {
      enable_cross_region_replication = false
      enable_mfa_delete               = false
      enable_inventory                = false
      enable_static_website           = true
      cors_origins                    = ["https://staging.${var.project_name}.com", "https://staging-admin.${var.project_name}.com"]
      enable_event_notifications      = false
      create_data_lake_bucket         = false
    }
    production = {
      enable_cross_region_replication = true
      enable_mfa_delete               = true
      enable_inventory                = true
      enable_static_website           = true
      cors_origins                    = ["https://${var.project_name}.com", "https://admin.${var.project_name}.com"]
      enable_event_notifications      = true
      create_data_lake_bucket         = true
    }
  }

  # Current environment configuration
  current_s3_config = local.s3_config[var.environment == "dev" ? "development" : var.environment == "prod" ? "production" : "staging"]

  # CORS rules for static assets
  cors_rules = length(local.current_s3_config.cors_origins) > 0 ? [
    {
      allowed_headers = ["*"]
      allowed_methods = ["GET", "HEAD"]
      allowed_origins = local.current_s3_config.cors_origins
      expose_headers  = ["ETag"]
      max_age_seconds = 3000
    }
  ] : []
}

# Provider for cross-region replication (us-west-2)
provider "aws" {
  alias   = "replica"
  region  = "us-west-2"
  profile = var.aws_profile

  default_tags {
    tags = merge(var.common_tags, {
      Environment = var.environment
      Region      = "us-west-2"
      Purpose     = "replication"
    })
  }
}

# S3 infrastructure using our custom module
module "s3" {
  source = "../modules/s3"

  # Basic configuration
  name_prefix = local.s3_name_prefix
  environment = var.environment == "dev" ? "development" : var.environment == "prod" ? "production" : "staging"
  region      = var.aws_region

  # Bucket creation flags
  create_application_bucket   = true
  create_backup_bucket        = true
  create_logs_bucket          = true
  create_static_assets_bucket = true
  create_compliance_bucket    = true
  create_data_lake_bucket     = local.current_s3_config.create_data_lake_bucket

  # Security configuration
  enable_versioning             = true
  enable_mfa_delete             = var.enable_s3_mfa_delete
  enable_server_side_encryption = true
  # kms_key_id is null to use module-generated KMS key

  # Public access configuration
  public_read_buckets = var.environment != "dev" && local.current_s3_config.enable_static_website ? ["static-assets"] : []

  # Lifecycle management (intelligent tiering enabled for cost optimization)
  enable_intelligent_tiering = true

  # Cross-region replication for disaster recovery (DISABLED for cost optimization)
  enable_cross_region_replication = var.enable_s3_cross_region_replication
  replication_destination_region  = "us-west-2"
  replicate_buckets               = ["application", "backup", "compliance"]

  # Access logging
  enable_access_logging = true

  # Monitoring
  enable_metrics   = true
  enable_inventory = local.current_s3_config.enable_inventory

  # Event notifications (for production monitoring)
  enable_event_notifications = local.current_s3_config.enable_event_notifications

  # VPC integration
  vpc_id = module.vpc.vpc_id
  vpc_endpoint_route_table_ids = concat(
    [module.vpc.public_route_table_id, module.vpc.data_route_table_id],
    module.vpc.private_route_table_ids
  )

  # CORS configuration for static assets
  cors_rules = local.cors_rules

  # Website configuration
  enable_static_website  = local.current_s3_config.enable_static_website
  website_index_document = "index.html"
  website_error_document = "error.html"

  # Cost optimization
  request_payer = "BucketOwner"

  # Tags
  tags = merge(local.common_tags, {
    Module    = "s3"
    Component = "storage"
    Tier      = "data"
  })

  # Additional tags per bucket type
  additional_bucket_tags = {
    application = {
      DataClassification = "internal"
      BackupRequired     = "true"
    }
    backup = {
      DataClassification = "internal"
      RetentionPeriod    = var.environment == "production" ? "7-years" : "1-year"
    }
    logs = {
      DataClassification = "internal"
      RetentionPeriod    = "7-years"
      Purpose            = "audit-logging"
    }
    static-assets = {
      DataClassification = "public"
      CDNEnabled         = "true"
      CacheControl       = "max-age=31536000"
    }
    compliance = {
      DataClassification = "confidential"
      RetentionPeriod    = "permanent"
      ComplianceRequired = "true"
    }
    data-lake = {
      DataClassification = "internal"
      Purpose            = "analytics"
      DataFormat         = "parquet"
    }
  }

  providers = {
    aws.replica = aws.replica
  }
}

# CloudWatch Log Group for S3 access logs analysis
resource "aws_cloudwatch_log_group" "s3_access_analysis" {
  count = var.enable_detailed_monitoring ? 1 : 0

  name              = "/aws/s3/access-analysis/${var.project_name}-${var.environment}"
  retention_in_days = var.environment == "prod" ? 90 : 30

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-${var.environment}-s3-access-analysis"
    Purpose = "s3-access-monitoring"
  })
}

# CloudWatch dashboard for S3 monitoring
resource "aws_cloudwatch_dashboard" "s3_monitoring" {
  count = var.enable_detailed_monitoring ? 1 : 0

  dashboard_name = "${var.project_name}-${var.environment}-s3-monitoring"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/S3", "BucketSizeBytes", "BucketName", module.s3.application_bucket_name, "StorageType", "StandardStorage"],
            ["AWS/S3", "BucketSizeBytes", "BucketName", module.s3.backup_bucket_name, "StorageType", "StandardStorage"],
            ["AWS/S3", "BucketSizeBytes", "BucketName", module.s3.logs_bucket_name, "StorageType", "StandardStorage"]
          ]
          period = 86400
          stat   = "Average"
          region = var.aws_region
          title  = "S3 Bucket Sizes"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/S3", "NumberOfObjects", "BucketName", module.s3.application_bucket_name, "StorageType", "AllStorageTypes"],
            ["AWS/S3", "NumberOfObjects", "BucketName", module.s3.backup_bucket_name, "StorageType", "AllStorageTypes"],
            ["AWS/S3", "NumberOfObjects", "BucketName", module.s3.logs_bucket_name, "StorageType", "AllStorageTypes"]
          ]
          period = 86400
          stat   = "Average"
          region = var.aws_region
          title  = "S3 Object Counts"
        }
      }
    ]
  })

  # CloudWatch dashboards don't support tags directly
  # tags = local.common_tags
}

# Output S3 information for use by other resources
output "s3_bucket_names" {
  description = "Map of S3 bucket names"
  value       = module.s3.bucket_names
}

output "s3_bucket_arns" {
  description = "Map of S3 bucket ARNs"
  value       = module.s3.bucket_arns
}

output "s3_application_bucket" {
  description = "Application bucket information"
  value = {
    name = module.s3.application_bucket_name
    arn  = module.s3.application_bucket_arn
  }
}

output "s3_backup_bucket" {
  description = "Backup bucket information"
  value = {
    name = module.s3.backup_bucket_name
    arn  = module.s3.backup_bucket_arn
  }
}

output "s3_logs_bucket" {
  description = "Logs bucket information"
  value = {
    name = module.s3.logs_bucket_name
    arn  = module.s3.logs_bucket_arn
  }
}

output "s3_static_assets_bucket" {
  description = "Static assets bucket information"
  value = {
    name             = module.s3.static_assets_bucket_name
    arn              = module.s3.static_assets_bucket_arn
    website_endpoint = module.s3.static_assets_website_endpoint
  }
}

output "s3_compliance_bucket" {
  description = "Compliance bucket information"
  value = {
    name = module.s3.compliance_bucket_name
    arn  = module.s3.compliance_bucket_arn
  }
}

output "s3_kms_key" {
  description = "S3 encryption key information"
  value = {
    id    = module.s3.kms_key_id
    arn   = module.s3.kms_key_arn
    alias = module.s3.kms_key_alias
  }
}

output "s3_configuration_summary" {
  description = "S3 configuration summary"
  value       = module.s3.configuration_summary
}
