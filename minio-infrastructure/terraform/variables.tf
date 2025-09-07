# Variables for MinIO Standalone Infrastructure

variable "project_name" {
  description = "Name of the MinIO project"
  type        = string
  default     = "minio-standalone"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "aws_region" {
  description = "AWS region for MinIO resources"
  type        = string
  default     = "us-east-2"
}

variable "aws_profile" {
  description = "AWS profile to use for authentication"
  type        = string
  default     = "default"
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30

  validation {
    condition     = var.log_retention_days >= 1 && var.log_retention_days <= 365
    error_message = "Log retention days must be between 1 and 365."
  }
}

variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring for S3 buckets"
  type        = bool
  default     = true
}

variable "enable_versioning" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = true
}

variable "enable_lifecycle" {
  description = "Enable S3 bucket lifecycle policies"
  type        = bool
  default     = true
}

variable "minio_root_user" {
  description = "MinIO root username"
  type        = string
  default     = "minioadmin"
  sensitive   = false
}

variable "minio_root_password" {
  description = "MinIO root password"
  type        = string
  default     = "minioadmin123"
  sensitive   = true
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access MinIO"
  type        = list(string)
  default     = ["10.10.10.0/24"] # LXD network range
}

# Optional: Custom bucket names (will use defaults if not provided)
variable "custom_bucket_names" {
  description = "Custom names for MinIO buckets"
  type = object({
    data    = optional(string, null)
    backups = optional(string, null)
    uploads = optional(string, null)
    logs    = optional(string, null)
  })
  default = {}
}

variable "s3_force_destroy" {
  description = "Allow Terraform to destroy S3 buckets even if they contain objects"
  type        = bool
  default     = false
}

variable "enable_cost_optimization" {
  description = "Enable cost optimization features (lifecycle policies, intelligent tiering)"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain backup objects in S3"
  type        = number
  default     = 90

  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 2555
    error_message = "Backup retention days must be between 7 and 2555 (7 years)."
  }
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "MinIO-Standalone"
    ManagedBy   = "Terraform"
    Owner       = "DevOps-Team"
    Component   = "object-storage"
  }
}
