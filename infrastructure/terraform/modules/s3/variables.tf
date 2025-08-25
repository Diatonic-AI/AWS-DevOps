# S3 Module Variables
# Enterprise-grade S3 configuration for multi-purpose bucket deployment

variable "name_prefix" {
  description = "Name prefix for all S3 resources"
  type        = string
  validation {
    condition     = length(var.name_prefix) <= 30 && can(regex("^[a-z0-9-]+$", var.name_prefix))
    error_message = "Name prefix must be 30 characters or less and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}

variable "region" {
  description = "AWS region for S3 buckets"
  type        = string
  default     = null
}

# Bucket Configuration
variable "create_application_bucket" {
  description = "Whether to create application data bucket"
  type        = bool
  default     = true
}

variable "create_backup_bucket" {
  description = "Whether to create backup bucket"
  type        = bool
  default     = true
}

variable "create_logs_bucket" {
  description = "Whether to create logs bucket"
  type        = bool
  default     = true
}

variable "create_static_assets_bucket" {
  description = "Whether to create static assets bucket (for CDN)"
  type        = bool
  default     = true
}

variable "create_compliance_bucket" {
  description = "Whether to create compliance/audit bucket"
  type        = bool
  default     = true
}

variable "create_data_lake_bucket" {
  description = "Whether to create data lake bucket for analytics"
  type        = bool
  default     = false
}

# Security Configuration
variable "enable_versioning" {
  description = "Enable versioning on buckets"
  type        = bool
  default     = true
}

variable "enable_mfa_delete" {
  description = "Enable MFA delete (requires versioning)"
  type        = bool
  default     = false # Set to true for production when MFA is configured
}

variable "kms_key_id" {
  description = "KMS key ID for bucket encryption (uses AWS managed key if null)"
  type        = string
  default     = null
}

variable "enable_server_side_encryption" {
  description = "Enable server-side encryption"
  type        = bool
  default     = true
}

variable "public_read_buckets" {
  description = "List of bucket types that should allow public read access"
  type        = list(string)
  default     = [] # No public access by default
  validation {
    condition = alltrue([
      for bucket in var.public_read_buckets : contains(["static-assets"], bucket)
    ])
    error_message = "Only 'static-assets' bucket can have public read access."
  }
}

# Lifecycle Configuration
variable "enable_intelligent_tiering" {
  description = "Enable intelligent tiering for cost optimization"
  type        = bool
  default     = true
}

# Lifecycle Rules Configuration Requirements:
# - INTELLIGENT_TIERING is only applied when no custom transitions are defined
# - All transitions must have at least 30 days between storage class changes
# - STANDARD_IA/ONEZONE_IA transitions must be at least 30 days from object creation
# - DEEP_ARCHIVE transitions must be at least 90 days after GLACIER transitions
variable "lifecycle_rules" {
  description = "Lifecycle rules for different bucket types"
  type = map(object({
    enabled = bool
    transitions = optional(list(object({
      days          = number
      storage_class = string
    })), [])
    expiration_days                    = optional(number, null)
    noncurrent_version_expiration_days = optional(number, null)
  }))
  default = {
    application = {
      enabled = true
      transitions = [
        { days = 30, storage_class = "STANDARD_IA" },
        { days = 90, storage_class = "GLACIER" },
        { days = 365, storage_class = "DEEP_ARCHIVE" }
      ]
      noncurrent_version_expiration_days = 90
    }
    backup = {
      enabled = true
      transitions = [
        { days = 30, storage_class = "GLACIER" },
        { days = 180, storage_class = "DEEP_ARCHIVE" }
      ]
      noncurrent_version_expiration_days = 30
    }
    logs = {
      enabled = true
      transitions = [
        { days = 30, storage_class = "STANDARD_IA" },
        { days = 90, storage_class = "GLACIER" }
      ]
      expiration_days                    = 2555 # 7 years for compliance
      noncurrent_version_expiration_days = 30
    }
    static-assets = {
      enabled = true
      transitions = [
        { days = 90, storage_class = "STANDARD_IA" }
      ]
      noncurrent_version_expiration_days = 30
    }
    compliance = {
      enabled = true
      transitions = [
        { days = 90, storage_class = "GLACIER" },
        { days = 365, storage_class = "DEEP_ARCHIVE" }
      ]
      # No expiration for compliance data
      noncurrent_version_expiration_days = 2555 # 7 years
    }
    data-lake = {
      enabled = true
      transitions = [
        { days = 90, storage_class = "STANDARD_IA" },
        { days = 180, storage_class = "GLACIER" }
      ]
      noncurrent_version_expiration_days = 365
    }
  }
}

# Cross-Region Replication
variable "enable_cross_region_replication" {
  description = "Enable cross-region replication for disaster recovery"
  type        = bool
  default     = false
}

variable "replication_destination_region" {
  description = "Destination region for cross-region replication"
  type        = string
  default     = "us-west-2"
}

variable "replicate_buckets" {
  description = "List of bucket types to replicate"
  type        = list(string)
  default     = ["application", "backup", "compliance"]
  validation {
    condition = alltrue([
      for bucket in var.replicate_buckets : contains([
        "application", "backup", "logs", "static-assets", "compliance", "data-lake"
      ], bucket)
    ])
    error_message = "Invalid bucket type for replication."
  }
}

# Access Logging
variable "enable_access_logging" {
  description = "Enable access logging for buckets"
  type        = bool
  default     = true
}

# Notification Configuration
variable "enable_event_notifications" {
  description = "Enable S3 event notifications"
  type        = bool
  default     = false
}

variable "notification_lambda_arn" {
  description = "Lambda function ARN for S3 event notifications"
  type        = string
  default     = null
}

variable "notification_sns_topic_arn" {
  description = "SNS topic ARN for S3 event notifications"
  type        = string
  default     = null
}

# VPC Integration
variable "vpc_id" {
  description = "VPC ID for VPC endpoint integration"
  type        = string
  default     = null
}

variable "vpc_endpoint_route_table_ids" {
  description = "Route table IDs for VPC endpoint"
  type        = list(string)
  default     = []
}

# Cost Optimization
variable "request_payer" {
  description = "Who pays for requests (BucketOwner or Requester)"
  type        = string
  default     = "BucketOwner"
  validation {
    condition     = contains(["BucketOwner", "Requester"], var.request_payer)
    error_message = "Request payer must be either BucketOwner or Requester."
  }
}

# Monitoring
variable "enable_metrics" {
  description = "Enable CloudWatch metrics for buckets"
  type        = bool
  default     = true
}

variable "enable_inventory" {
  description = "Enable S3 inventory for cost optimization"
  type        = bool
  default     = false # Enable in production for large deployments
}

# CORS Configuration
variable "cors_rules" {
  description = "CORS rules for static assets bucket"
  type = list(object({
    allowed_headers = list(string)
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = optional(list(string), [])
    max_age_seconds = optional(number, 3000)
  }))
  default = []
}

# Website Configuration
variable "enable_static_website" {
  description = "Enable static website hosting for static assets bucket"
  type        = bool
  default     = false
}

variable "website_index_document" {
  description = "Index document for static website"
  type        = string
  default     = "index.html"
}

variable "website_error_document" {
  description = "Error document for static website"
  type        = string
  default     = "error.html"
}

# Tags
variable "tags" {
  description = "Tags to apply to all S3 resources"
  type        = map(string)
  default     = {}
}

variable "additional_bucket_tags" {
  description = "Additional tags for specific bucket types"
  type        = map(map(string))
  default     = {}
}
