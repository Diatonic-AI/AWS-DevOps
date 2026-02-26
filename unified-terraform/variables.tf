# Unified Variables Configuration
# Consolidates all variables from different Terraform roots

# Project and Environment Configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "aws-devops"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-2"

  validation {
    condition = contains([
      "us-east-1", "us-east-2", "us-west-1", "us-west-2",
      "eu-west-1", "eu-west-2", "eu-central-1", "ap-southeast-1"
    ], var.aws_region)
    error_message = "AWS region must be a valid AWS region."
  }
}

variable "aws_profile" {
  description = "AWS profile to use for authentication"
  type        = string
  default     = "default"
}

# Common Tags
variable "common_tags" {
  description = "Common tags to be applied to all resources"
  type        = map(string)
  default = {
    Project    = "AWS-DevOps"
    ManagedBy  = "Terraform-Unified"
    Owner      = "DevOps Team"
    Repository = "AWS-DevOps"
    Framework  = "Unified"
  }
}

# Notification Configuration
variable "notification_email" {
  description = "Email address for alerts and notifications"
  type        = string
  default     = null

  validation {
    condition     = var.notification_email == null || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.notification_email))
    error_message = "Notification email must be a valid email address."
  }
}

# Security Configuration
variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access resources"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.allowed_cidr_blocks : can(cidrhost(cidr, 0))
    ])
    error_message = "All CIDR blocks must be valid."
  }
}

# Domain and SSL Configuration
variable "domain_name" {
  description = "Primary domain name for applications"
  type        = string
  default     = "diatonic.ai"
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
  default     = null
}

variable "certificate_arn_us_east_1" {
  description = "ACM certificate ARN in us-east-1 for CloudFront"
  type        = string
  default     = null
}

variable "certificate_arn_us_east_2" {
  description = "ACM certificate ARN in us-east-2 for ALB"
  type        = string
  default     = null
}

variable "diatonic_ssl_certificate_arn" {
  description = "ACM certificate ARN for diatonic.ai (must be in us-east-1 for CloudFront)"
  type        = string
  default     = null
}

# Cloudflare Configuration
variable "enable_cloudflare" {
  description = "Enable Cloudflare DNS and CDN integration"
  type        = bool
  default     = false
}

variable "cloudflare_api_token" {
  description = "Cloudflare API Token (optional - use this OR api_key + email)"
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = var.cloudflare_api_token == null || var.cloudflare_api_token == "" || length(var.cloudflare_api_token) > 10
    error_message = "Cloudflare API token must be at least 10 characters long when provided."
  }
}

variable "cloudflare_api_key" {
  description = "Cloudflare Global API Key (legacy authentication)"
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = var.cloudflare_api_key == null || var.cloudflare_api_key == "" || length(var.cloudflare_api_key) > 30
    error_message = "Cloudflare API key must be at least 30 characters long when provided."
  }
}

variable "cloudflare_email" {
  description = "Cloudflare account email (required when using Global API Key)"
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = var.cloudflare_email == null || var.cloudflare_email == "" || can(regex("^[\\w\\.-]+@[\\w\\.-]+\\.[a-zA-Z]{2,}$", var.cloudflare_email))
    error_message = "Cloudflare email must be a valid email address when provided."
  }
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for the domain"
  type        = string
  default     = "f889715fdbadcf662ea496b8e40ee6eb" # diatonic.ai zone ID
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID"
  type        = string
  default     = "35043351f8c199237f5ebd11f4a27c15"
}

variable "default_cloudfront_domain" {
  description = "Default CloudFront domain if AI Nexus module is not enabled (production)"
  type        = string
  default     = "d1bw1xopa9byqn.cloudfront.net"
}

variable "dev_cloudfront_domain" {
  description = "CloudFront domain for development environment"
  type        = string
  default     = "d34iz6fjitwuax.cloudfront.net"
}

variable "api_custom_domain" {
  description = "Custom API domain name (optional)"
  type        = string
  default     = null
}

# Feature Flags - Global
variable "feature_flags" {
  description = "Global feature flags for enabling/disabling functionality"
  type = object({
    enable_cloudtrail   = optional(bool, true)
    enable_config       = optional(bool, false)
    enable_guardduty    = optional(bool, false)
    enable_security_hub = optional(bool, false)
    enable_cost_alerts  = optional(bool, true)
    enable_multi_az     = optional(bool, true)
  })
  default = {}
}

# AI Nexus Workbench Configuration
variable "ai_nexus_config" {
  description = "AI Nexus Workbench specific configuration"
  type = object({
    enable_cognito         = optional(bool, true)
    enable_api_gateway     = optional(bool, true)
    enable_lambda          = optional(bool, true)
    enable_dynamodb        = optional(bool, true)
    enable_s3_uploads      = optional(bool, true)
    enable_stripe_billing  = optional(bool, false)
    cognito_user_pool_name = optional(string, "ai-nexus-users")
    api_stage_name         = optional(string, "v1")
    lambda_runtime         = optional(string, "python3.9")
    lambda_timeout         = optional(number, 30)
    lambda_memory_size     = optional(number, 256)
    dynamodb_billing_mode  = optional(string, "PAY_PER_REQUEST")
    s3_cors_origins        = optional(list(string), ["*"])
  })
  default = {}
}

# MinIO Configuration
variable "minio_config" {
  description = "MinIO infrastructure configuration"
  type = object({
    instance_type         = optional(string, "t3.micro")
    volume_size           = optional(number, 20)
    enable_ssl            = optional(bool, true)
    enable_versioning     = optional(bool, true)
    backup_retention_days = optional(number, 30)
  })
  default = {}
}

# Web Application Configuration
variable "web_app_config" {
  description = "Web application configuration"
  type = object({
    enable_web_application = optional(bool, true)
    container_image        = optional(string, "nginx:alpine")
    container_port         = optional(number, 80)
    health_check_path      = optional(string, "/")
    enable_cloudfront      = optional(bool, true)
    enable_waf             = optional(bool, false)
    enable_alb             = optional(bool, true)
  })
  default = {}
}

# Database Configuration
variable "database_config" {
  description = "Database configuration options"
  type = object({
    enable_rds              = optional(bool, false)
    engine                  = optional(string, "mysql")
    engine_version          = optional(string, "8.0")
    instance_class          = optional(string, "db.t3.micro")
    allocated_storage       = optional(number, 20)
    backup_window           = optional(string, "03:00-04:00")
    maintenance_window      = optional(string, "sun:04:00-sun:05:00")
    backup_retention_period = optional(number, 7)
  })
  default = {}
}

# Monitoring Configuration
variable "monitoring_config" {
  description = "Monitoring and alerting configuration"
  type = object({
    enable_cloudwatch_dashboard = optional(bool, true)
    enable_sns_alerts           = optional(bool, true)
    cpu_alarm_threshold         = optional(number, 80)
    memory_alarm_threshold      = optional(number, 80)
    disk_alarm_threshold        = optional(number, 85)
    log_retention_days          = optional(number, 30)
    enable_xray                 = optional(bool, false)
  })
  default = {}
}

# Cost Optimization Configuration
variable "cost_optimization" {
  description = "Cost optimization settings"
  type = object({
    enable_spot_instances    = optional(bool, false)
    enable_scheduled_scaling = optional(bool, true)
    scale_down_schedule      = optional(string, "0 19 * * MON-FRI") # 7 PM weekdays
    scale_up_schedule        = optional(string, "0 8 * * MON-FRI")  # 8 AM weekdays
    weekend_scale_down       = optional(bool, true)
    enable_right_sizing      = optional(bool, true)
  })
  default = {}
}

# Backup Configuration
variable "backup_config" {
  description = "Backup and disaster recovery configuration"
  type = object({
    enable_aws_backup          = optional(bool, true)
    backup_vault_name          = optional(string, "aws-devops-backup-vault")
    backup_schedule            = optional(string, "cron(0 2 * * ? *)") # Daily at 2 AM
    backup_retention_days      = optional(number, 30)
    backup_cold_storage_days   = optional(number, 90)
    backup_delete_days         = optional(number, 365)
    enable_cross_region_backup = optional(bool, false)
    backup_target_region       = optional(string, "us-west-2")
  })
  default = {}
}

# Security Configuration
variable "security_config" {
  description = "Security-specific configuration"
  type = object({
    enable_vpc_flow_logs   = optional(bool, true)
    enable_cloudtrail      = optional(bool, true)
    enable_config_rules    = optional(bool, false)
    enable_guardduty       = optional(bool, false)
    enable_security_hub    = optional(bool, false)
    enable_inspector       = optional(bool, false)
    enable_secrets_manager = optional(bool, true)
    force_ssl              = optional(bool, true)
    min_tls_version        = optional(string, "TLSv1.2")
    enable_mfa_delete      = optional(bool, false)
  })
  default = {}
}

# Networking Configuration
variable "network_config" {
  description = "Network-specific configuration overrides"
  type = object({
    vpc_cidr_override     = optional(string, null)
    enable_ipv6           = optional(bool, false)
    enable_dns_hostnames  = optional(bool, true)
    enable_dns_support    = optional(bool, true)
    enable_vpc_endpoints  = optional(bool, true)
    nat_gateway_single_az = optional(bool, true) # Cost optimization
    enable_nat_instance   = optional(bool, false)
  })
  default = {}

  validation {
    condition     = var.network_config.vpc_cidr_override == null || can(cidrhost(var.network_config.vpc_cidr_override, 0))
    error_message = "VPC CIDR override must be a valid CIDR block."
  }
}

# Application Environment Variables
variable "application_environment_variables" {
  description = "Environment variables for applications"
  type        = map(string)
  default     = {}
  sensitive   = true
}

# Workspace-specific Overrides
variable "workspace_overrides" {
  description = "Workspace-specific configuration overrides"
  type = map(object({
    environment_name = optional(string)
    vpc_cidr         = optional(string)
    instance_types   = optional(map(string))
    scaling_config   = optional(map(number))
  }))
  default = {}
}

# Emergency Override Flags
variable "emergency_overrides" {
  description = "Emergency override flags for maintenance and disaster recovery"
  type = object({
    disable_deletion_protection = optional(bool, false)
    enable_debug_logging        = optional(bool, false)
    bypass_approval_gates       = optional(bool, false)
    emergency_contact_email     = optional(string, null)
  })
  default   = {}
  sensitive = true
}
