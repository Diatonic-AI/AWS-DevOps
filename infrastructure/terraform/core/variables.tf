# Core Infrastructure Variables
# These variables are used across all core infrastructure components

# Project Information
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "aws-devops"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
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

# AWS Configuration
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
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
    ManagedBy  = "Terraform"
    Owner      = "DevOps Team"
    Repository = "AWS-DevOps"
  }
}

# VPC Configuration (Optional overrides - defaults are calculated in vpc.tf)
variable "vpc_cidr_override" {
  description = "Override the default VPC CIDR block"
  type        = string
  default     = null

  validation {
    condition     = var.vpc_cidr_override == null || can(cidrhost(var.vpc_cidr_override, 0))
    error_message = "VPC CIDR override must be a valid CIDR block."
  }
}

# Backup and Recovery Configuration
variable "enable_backup" {
  description = "Enable AWS Backup for supported resources"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30

  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 365
    error_message = "Backup retention days must be between 7 and 365."
  }
}

# Monitoring Configuration
variable "enable_detailed_monitoring" {
  description = "Enable detailed monitoring for resources"
  type        = bool
  default     = false # Set to true for production
}

variable "notification_email" {
  description = "Email address for alerts and notifications"
  type        = string
  default     = null

  validation {
    condition     = var.notification_email == null || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.notification_email))
    error_message = "Notification email must be a valid email address."
  }
}

# Cost Optimization
variable "enable_cost_optimization" {
  description = "Enable cost optimization features (spot instances, scheduled scaling, etc.)"
  type        = bool
  default     = true
}

# Security Configuration
variable "enable_security_features" {
  description = "Enable additional security features (GuardDuty, Config, etc.)"
  type        = bool
  default     = true
}

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

# Resource Naming
variable "name_prefix" {
  description = "Prefix to add to all resource names"
  type        = string
  default     = ""
}

variable "name_suffix" {
  description = "Suffix to add to all resource names"
  type        = string
  default     = ""
}

# Feature Flags
variable "feature_flags" {
  description = "Feature flags for enabling/disabling specific functionality"
  type = object({
    enable_nat_gateway   = optional(bool, true)
    enable_vpc_endpoints = optional(bool, true)
    enable_flow_logs     = optional(bool, true)
    enable_cloudtrail    = optional(bool, true)
    enable_config        = optional(bool, false)
    enable_guardduty     = optional(bool, false)
    enable_security_hub  = optional(bool, false)
  })
  default = {}
}

# Web Application Configuration
variable "web_app_container_image" {
  description = "Docker image for the web application (defaults to nginx:alpine)"
  type        = string
  default     = null
}

variable "web_app_domain_name" {
  description = "Custom domain name for the web application"
  type        = string
  default     = null
}

variable "enable_web_application" {
  description = "Enable web application infrastructure"
  type        = bool
  default     = true
}

variable "enable_database" {
  description = "Enable RDS database for the web application"
  type        = bool
  default     = false
}

# S3 Configuration
variable "enable_s3_versioning" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = true
}

variable "enable_s3_encryption" {
  description = "Enable S3 bucket encryption"
  type        = bool
  default     = true
}

variable "enable_s3_access_logging" {
  description = "Enable S3 access logging"
  type        = bool
  default     = true
}

variable "enable_s3_mfa_delete" {
  description = "Enable S3 MFA delete"
  type        = bool
  default     = false
}

variable "enable_s3_cross_region_replication" {
  description = "Enable S3 cross-region replication"
  type        = bool
  default     = false
}

variable "enable_s3_inventory" {
  description = "Enable S3 inventory"
  type        = bool
  default     = false
}

variable "enable_s3_event_notifications" {
  description = "Enable S3 event notifications"
  type        = bool
  default     = false
}

variable "s3_cors_origins" {
  description = "List of allowed CORS origins for S3 static assets"
  type        = list(string)
  default     = []
}

# Additional Configuration Variables
variable "container_image" {
  description = "Container image for the application"
  type        = string
  default     = "nginx:alpine"
}

variable "enable_cloudfront" {
  description = "Enable CloudFront CDN"
  type        = bool
  default     = true
}

variable "enable_route53" {
  description = "Enable Route53 DNS"
  type        = bool
  default     = true
}

variable "enable_https" {
  description = "Enable HTTPS"
  type        = bool
  default     = true
}

variable "enable_alb" {
  description = "Enable Application Load Balancer"
  type        = bool
  default     = true
}

variable "enable_ecs" {
  description = "Enable ECS"
  type        = bool
  default     = true
}

variable "ecs_cpu" {
  description = "ECS task CPU"
  type        = number
  default     = 256
}

variable "ecs_memory" {
  description = "ECS task memory"
  type        = number
  default     = 512
}

variable "min_capacity" {
  description = "Minimum capacity for auto scaling"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum capacity for auto scaling"
  type        = number
  default     = 3
}

variable "desired_capacity" {
  description = "Desired capacity for auto scaling"
  type        = number
  default     = 2
}

variable "target_cpu_utilization" {
  description = "Target CPU utilization for auto scaling"
  type        = number
  default     = 70
}

# Route53 Configuration
variable "create_hosted_zone" {
  description = "Create a new Route53 hosted zone"
  type        = bool
  default     = false
}

variable "existing_zone_id" {
  description = "Existing Route53 hosted zone ID"
  type        = string
  default     = null
}

variable "enable_health_checks" {
  description = "Enable Route53 health checks"
  type        = bool
  default     = true
}

# CloudFront Configuration
variable "cloudfront_price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_200"
}

variable "cloudfront_default_ttl" {
  description = "Default TTL for CloudFront"
  type        = number
  default     = 86400
}

variable "cloudfront_max_ttl" {
  description = "Maximum TTL for CloudFront"
  type        = number
  default     = 31536000
}

variable "cloudfront_min_ttl" {
  description = "Minimum TTL for CloudFront"
  type        = number
  default     = 0
}

variable "enable_cloudfront_logging" {
  description = "Enable CloudFront access logging"
  type        = bool
  default     = true
}

variable "enable_origin_shield" {
  description = "Enable CloudFront Origin Shield"
  type        = bool
  default     = false
}

# SSL/TLS Configuration
variable "ssl_support_method" {
  description = "SSL support method for CloudFront"
  type        = string
  default     = "sni-only"
}

variable "minimum_protocol_version" {
  description = "Minimum SSL/TLS protocol version"
  type        = string
  default     = "TLSv1.2_2021"
}

# Application Configuration
variable "application_port" {
  description = "Port the application listens on"
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "Health check path for the application"
  type        = string
  default     = "/"
}

variable "health_check_grace_period" {
  description = "Grace period for health checks in seconds"
  type        = number
  default     = 300
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

# Additional Missing Variables
variable "alb_name" {
  description = "Name for the Application Load Balancer"
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

variable "cloudfront_distribution_id" {
  description = "Existing CloudFront distribution ID to import"
  type        = string
  default     = null
}

variable "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  type        = string
  default     = null
}

variable "cluster_name" {
  description = "Name for the ECS cluster"
  type        = string
  default     = null
}

variable "container_cpu" {
  description = "CPU units for the container"
  type        = number
  default     = 256
}

variable "container_environment" {
  description = "Environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "container_memory" {
  description = "Memory (MB) for the container"
  type        = number
  default     = 512
}

variable "container_name" {
  description = "Name for the container"
  type        = string
  default     = null
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 80
}

variable "data_subnet_cidrs" {
  description = "CIDR blocks for data subnets"
  type        = list(string)
  default     = []
}

variable "domain_name" {
  description = "Primary domain name for the application"
  type        = string
  default     = null
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
  default     = null
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = []
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = []
}

variable "service_name" {
  description = "Name for the ECS service"
  type        = string
  default     = null
}

variable "task_family" {
  description = "ECS task definition family name"
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "Existing VPC ID to import"
  type        = string
  default     = null
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "healthy_threshold" {
  description = "Number of consecutive successful health checks before marking healthy"
  type        = number
  default     = 2
}

variable "unhealthy_threshold" {
  description = "Number of consecutive failed health checks before marking unhealthy"
  type        = number
  default     = 3
}

variable "enable_stickiness" {
  description = "Enable load balancer session stickiness"
  type        = bool
  default     = false
}

# Scaling Configuration
variable "enable_scheduled_scaling" {
  description = "Enable scheduled auto scaling"
  type        = bool
  default     = true
}

variable "scale_down_schedule" {
  description = "Cron expression for scaling down"
  type        = string
  default     = "0 2 * * *"
}

variable "scale_up_schedule" {
  description = "Cron expression for scaling up"
  type        = string
  default     = "0 8 * * *"
}

# Monitoring Configuration
variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch logs"
  type        = bool
  default     = true
}

variable "enable_access_logs" {
  description = "Enable access logs"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms"
  type        = bool
  default     = true
}

variable "cpu_alarm_threshold" {
  description = "CPU alarm threshold percentage"
  type        = number
  default     = 80
}

variable "memory_alarm_threshold" {
  description = "Memory alarm threshold percentage"
  type        = number
  default     = 80
}

variable "response_time_threshold" {
  description = "Response time alarm threshold in milliseconds"
  type        = number
  default     = 2000
}

variable "error_rate_threshold" {
  description = "Error rate alarm threshold percentage"
  type        = number
  default     = 5
}

variable "log_retention_days" {
  description = "Log retention period in days"
  type        = number
  default     = 30
}

# Security Configuration
variable "enable_waf" {
  description = "Enable AWS WAF"
  type        = bool
  default     = false
}

variable "force_ssl_redirect" {
  description = "Force SSL redirect"
  type        = bool
  default     = true
}

variable "security_headers_enabled" {
  description = "Enable security headers"
  type        = bool
  default     = true
}

# Application Environment Variables
variable "application_environment_variables" {
  description = "Environment variables for the application"
  type        = map(string)
  default     = {}
}

# TTL Configuration
variable "ttl_default" {
  description = "Default TTL for DNS records"
  type        = number
  default     = 300
}
