# Variables for Cost Explorer Cache module

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "enable_point_in_time_recovery" {
  description = "Enable point-in-time recovery for DynamoDB tables"
  type        = bool
  default     = false
}

variable "kms_key_id" {
  description = "KMS key ARN for DynamoDB encryption (leave empty for AWS managed key)"
  type        = string
  default     = ""
}

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms"
  type        = string
  default     = ""
}

variable "create_dashboard" {
  description = "Create CloudWatch dashboard for monitoring cache performance"
  type        = bool
  default     = true
}

variable "cache_ttl_hours" {
  description = "TTL for cache entries in hours"
  type        = number
  default     = 24

  validation {
    condition     = var.cache_ttl_hours > 0 && var.cache_ttl_hours <= 168 # Max 1 week
    error_message = "Cache TTL must be between 1 and 168 hours."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}