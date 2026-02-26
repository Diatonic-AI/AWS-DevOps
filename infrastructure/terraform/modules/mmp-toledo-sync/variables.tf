# MMP Toledo Sync Module Variables
# Optimized for cost-effectiveness and AWS Free Tier compatibility

# ============================================================================
# REQUIRED VARIABLES
# ============================================================================

variable "project_prefix" {
  description = "Project prefix for resource naming"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_prefix))
    error_message = "Project prefix must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

# ============================================================================
# SUPABASE CONFIGURATION
# ============================================================================

variable "supabase_url" {
  description = "Supabase project URL (e.g., https://xxxx.supabase.co)"
  type        = string

  validation {
    condition     = can(regex("^https://.*\\.supabase\\.co$", var.supabase_url))
    error_message = "Supabase URL must be in format: https://xxxx.supabase.co"
  }
}

variable "supabase_anon_key" {
  description = "Supabase anonymous/public API key (sb_publishable_xxx or eyJ...)"
  type        = string
  sensitive   = true
}

variable "supabase_service_role_key" {
  description = "Supabase service role key for admin operations"
  type        = string
  sensitive   = true
  default     = ""
}

variable "supabase_webhook_url" {
  description = "Supabase Edge Function webhook URL"
  type        = string

  validation {
    # Accepts both formats:
    # - https://xxxx.functions.supabase.co/function-name (Edge Functions v2)
    # - https://xxxx.supabase.co/functions/v1/function-name (Edge Functions v1)
    condition     = can(regex("^https://.*\\.supabase\\.co.*$", var.supabase_webhook_url))
    error_message = "Supabase webhook URL must be a valid Supabase URL."
  }
}

# ============================================================================
# DYNAMODB CONFIGURATION
# ============================================================================

variable "dynamodb_table_arns" {
  description = "List of DynamoDB table ARNs to sync"
  type        = list(string)

  validation {
    condition     = alltrue([for arn in var.dynamodb_table_arns : can(regex("^arn:aws:dynamodb:", arn))])
    error_message = "All ARNs must be valid DynamoDB table ARNs."
  }
}

variable "dynamodb_table_stream_arns" {
  description = "List of DynamoDB table stream ARNs"
  type        = list(string)

  validation {
    condition     = alltrue([for arn in var.dynamodb_table_stream_arns : can(regex("^arn:aws:dynamodb:.*/stream/", arn))])
    error_message = "All ARNs must be valid DynamoDB stream ARNs."
  }
}

variable "dynamodb_streams" {
  description = "Map of DynamoDB streams to sync with optional filter patterns"
  type = map(object({
    stream_arn     = string
    filter_pattern = optional(string) # Optional event filter pattern
  }))

  default = {}
}

# ============================================================================
# LAMBDA CONFIGURATION (Cost Optimized)
# ============================================================================

variable "lambda_memory_size" {
  description = "Lambda memory size in MB (128 is minimum and most cost-effective for simple HTTP calls)"
  type        = number
  default     = 128 # Minimum, sufficient for HTTP webhook calls

  validation {
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 10240
    error_message = "Lambda memory must be between 128 MB and 10240 MB."
  }
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30 # Sufficient for HTTP calls with retries

  validation {
    condition     = var.lambda_timeout >= 1 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 1 and 900 seconds."
  }
}

variable "reserved_concurrent_executions" {
  description = "Reserved concurrent executions (limits costs). Set to -1 for unreserved."
  type        = number
  default     = 5 # Low limit to prevent runaway costs

  validation {
    condition     = var.reserved_concurrent_executions == -1 || (var.reserved_concurrent_executions >= 1 && var.reserved_concurrent_executions <= 1000)
    error_message = "Reserved concurrent executions must be -1 (unreserved) or between 1 and 1000."
  }
}

# ============================================================================
# BATCH PROCESSING CONFIGURATION
# ============================================================================

variable "batch_size" {
  description = "Maximum number of records to process per Lambda invocation"
  type        = number
  default     = 10 # Process multiple records per invocation for efficiency

  validation {
    condition     = var.batch_size >= 1 && var.batch_size <= 10000
    error_message = "Batch size must be between 1 and 10000."
  }
}

variable "batching_window_seconds" {
  description = "Maximum time to wait for a batch to fill before invoking Lambda"
  type        = number
  default     = 5 # Wait up to 5 seconds to batch records

  validation {
    condition     = var.batching_window_seconds >= 0 && var.batching_window_seconds <= 300
    error_message = "Batching window must be between 0 and 300 seconds."
  }
}

# ============================================================================
# RETRY CONFIGURATION
# ============================================================================

variable "max_retries" {
  description = "Maximum number of retries for Supabase webhook calls"
  type        = number
  default     = 3

  validation {
    condition     = var.max_retries >= 1 && var.max_retries <= 10
    error_message = "Max retries must be between 1 and 10."
  }
}

variable "retry_delay_ms" {
  description = "Base delay in milliseconds between retries (multiplied by attempt number)"
  type        = number
  default     = 1000

  validation {
    condition     = var.retry_delay_ms >= 100 && var.retry_delay_ms <= 30000
    error_message = "Retry delay must be between 100 and 30000 milliseconds."
  }
}

variable "stream_max_retries" {
  description = "Maximum retry attempts for DynamoDB stream processing"
  type        = number
  default     = 2 # Keep low to avoid repeated failures

  validation {
    condition     = var.stream_max_retries >= 0 && var.stream_max_retries <= 10000
    error_message = "Stream max retries must be between 0 and 10000."
  }
}

# ============================================================================
# LOGGING CONFIGURATION
# ============================================================================

variable "log_retention_days" {
  description = "CloudWatch log retention in days (lower = lower cost)"
  type        = number
  default     = 7 # Short retention to minimize costs

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention must be a valid CloudWatch retention period."
  }
}

# ============================================================================
# MONITORING CONFIGURATION
# ============================================================================

variable "enable_monitoring" {
  description = "Enable CloudWatch alarms for monitoring"
  type        = bool
  default     = false # Disabled by default for cost optimization
}

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for alarm notifications"
  type        = string
  default     = null
}

# ============================================================================
# TAGGING
# ============================================================================

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "MMP-Toledo"
    ManagedBy = "Terraform"
    Component = "dynamodb-supabase-sync"
  }
}
