# MMP Toledo Sync - Root Variables
# Configure these variables in terraform.tfvars or via environment variables

# ============================================================================
# PROJECT CONFIGURATION
# ============================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "mmp-toledo"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"

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

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "default"
}

# ============================================================================
# SUPABASE CONFIGURATION
# ============================================================================

variable "supabase_url" {
  description = "Supabase project URL"
  type        = string
  default     = "https://jpcdwbkeivtmweoacbsh.supabase.co"
}

variable "supabase_anon_key" {
  description = "Supabase anonymous/publishable API key"
  type        = string
  sensitive   = true
  # Set via: TF_VAR_supabase_anon_key or terraform.tfvars
}

variable "supabase_service_role_key" {
  description = "Supabase service role key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "supabase_webhook_url" {
  description = "Supabase Edge Function webhook URL"
  type        = string
  default     = "https://jpcdwbkeivtmweoacbsh.functions.supabase.co/mmp-toledo-sync"
}

# ============================================================================
# DYNAMODB TABLE CONFIGURATION
# ============================================================================

variable "enable_leads_table_sync" {
  description = "Enable sync for MMP Toledo leads table"
  type        = bool
  default     = true
}

variable "leads_table_name" {
  description = "Name of the MMP Toledo leads DynamoDB table"
  type        = string
  default     = "mmp-toledo-leads-prod"
}

variable "enable_otp_table_sync" {
  description = "Enable sync for MMP Toledo OTP table"
  type        = bool
  default     = false
}

variable "otp_table_name" {
  description = "Name of the MMP Toledo OTP DynamoDB table"
  type        = string
  default     = "mmp-toledo-otp-prod"
}

variable "enable_dashboard_table_sync" {
  description = "Enable sync for Toledo dashboard table"
  type        = bool
  default     = true
}

variable "dashboard_table_name" {
  description = "Name of the Toledo dashboard DynamoDB table"
  type        = string
  default     = "toledo-consulting-dashboard-data"
}

variable "create_dynamodb_tables" {
  description = "Create DynamoDB tables if they don't exist"
  type        = bool
  default     = false
}

variable "additional_dynamodb_streams" {
  description = "Additional DynamoDB streams to sync (beyond leads and otp)"
  type = map(object({
    stream_arn     = string
    filter_pattern = optional(string)
  }))
  default = {}
}

# ============================================================================
# FIRESPRING SYNC CONFIGURATION (us-east-1)
# ============================================================================

variable "enable_firespring_sync" {
  description = "Enable sync for Firespring tables in us-east-1"
  type        = bool
  default     = false
}

# ============================================================================
# LAMBDA CONFIGURATION (Cost Optimized)
# ============================================================================

variable "lambda_memory_size" {
  description = "Lambda memory in MB (128 is minimum and most cost-effective)"
  type        = number
  default     = 128
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "reserved_concurrent_executions" {
  description = "Reserved concurrent executions to limit costs"
  type        = number
  default     = 5
}

# ============================================================================
# BATCH PROCESSING
# ============================================================================

variable "batch_size" {
  description = "Max records per Lambda invocation"
  type        = number
  default     = 10
}

variable "batching_window_seconds" {
  description = "Max time to wait for batch to fill"
  type        = number
  default     = 5
}

# ============================================================================
# RETRY CONFIGURATION
# ============================================================================

variable "max_retries" {
  description = "Max retries for Supabase webhook calls"
  type        = number
  default     = 3
}

variable "retry_delay_ms" {
  description = "Base retry delay in milliseconds"
  type        = number
  default     = 1000
}

variable "stream_max_retries" {
  description = "Max retries for DynamoDB stream processing"
  type        = number
  default     = 2
}

# ============================================================================
# LOGGING
# ============================================================================

variable "log_retention_days" {
  description = "CloudWatch log retention (shorter = lower cost)"
  type        = number
  default     = 7
}

# ============================================================================
# MONITORING
# ============================================================================

variable "enable_monitoring" {
  description = "Enable CloudWatch alarms"
  type        = bool
  default     = false
}

variable "alarm_sns_topic_arn" {
  description = "SNS topic for alarms"
  type        = string
  default     = null
}

# ============================================================================
# TAGS
# ============================================================================

variable "default_tags" {
  description = "Default tags for all resources"
  type        = map(string)
  default = {
    Project    = "MMP-Toledo"
    ManagedBy  = "Terraform"
    Component  = "dynamodb-supabase-sync"
    CostCenter = "mmp-toledo"
  }
}
