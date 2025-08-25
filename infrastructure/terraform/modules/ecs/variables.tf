# ECS Fargate Module Variables
# Cost-optimized containerized compute for web applications

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where ECS resources will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for load balancer"
  type        = list(string)
}

variable "application_port" {
  description = "Port the application listens on"
  type        = number
  default     = 3000
}

variable "health_check_path" {
  description = "Health check path for the application"
  type        = string
  default     = "/"
}

# Container Configuration
variable "container_image" {
  description = "Docker image for the application"
  type        = string
  default     = "nginx:latest" # Default to nginx for static sites
}

variable "container_port" {
  description = "Port the container exposes"
  type        = number
  default     = 80
}

variable "container_cpu" {
  description = "CPU units for the container (256, 512, 1024, etc.)"
  type        = number
  default     = 256 # Cheapest option
}

variable "container_memory" {
  description = "Memory for the container in MB (512, 1024, 2048, etc.)"
  type        = number
  default     = 512 # Cheapest option
}

# Scaling Configuration
variable "min_capacity" {
  description = "Minimum number of tasks"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of tasks"
  type        = number
  default     = 10
}

variable "desired_capacity" {
  description = "Desired number of tasks"
  type        = number
  default     = 1
}

# Cost Optimization
variable "enable_auto_scaling" {
  description = "Enable auto scaling for cost optimization"
  type        = bool
  default     = true
}

variable "scale_up_cpu_threshold" {
  description = "CPU utilization threshold to scale up"
  type        = number
  default     = 70
}

variable "scale_down_cpu_threshold" {
  description = "CPU utilization threshold to scale down"
  type        = number
  default     = 30
}

# Environment Variables
variable "environment_variables" {
  description = "Environment variables for the container"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

# Secrets (for sensitive data)
variable "secrets" {
  description = "Secrets from Systems Manager Parameter Store"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

# Domain and SSL
variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = null
}

variable "enable_https" {
  description = "Enable HTTPS with SSL certificate"
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ARN of SSL certificate (if enable_https is true)"
  type        = string
  default     = null
}

# Logging
variable "enable_logging" {
  description = "Enable CloudWatch logging"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Log retention period in days"
  type        = number
  default     = 7 # Cost optimization for dev
}

# Security
variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the application"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Open for dev, restrict for production
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Database Integration
variable "database_endpoint" {
  description = "RDS database endpoint"
  type        = string
  default     = null
}

variable "database_port" {
  description = "RDS database port"
  type        = number
  default     = 3306
}

variable "database_name" {
  description = "Database name"
  type        = string
  default     = null
}

# Redis Integration
variable "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  type        = string
  default     = null
}

variable "redis_port" {
  description = "ElastiCache Redis port"
  type        = number
  default     = 6379
}
