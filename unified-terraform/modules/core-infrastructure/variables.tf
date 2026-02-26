# Core Infrastructure Module Variables

# Required Variables
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "unique_suffix" {
  description = "Unique suffix for resource names"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid CIDR block."
  }
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

# NAT Gateway Configuration
variable "nat_gateway_count" {
  description = "Number of NAT Gateways to create"
  type        = number
  default     = 1

  validation {
    condition     = var.nat_gateway_count >= 1 && var.nat_gateway_count <= 3
    error_message = "NAT Gateway count must be between 1 and 3."
  }
}

variable "enable_nat_instance" {
  description = "Use NAT instance instead of NAT Gateway for cost optimization"
  type        = bool
  default     = false
}

variable "key_name" {
  description = "EC2 Key Pair name for NAT instance"
  type        = string
  default     = null
}

# Feature Flags
variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = true
}

variable "enable_backup" {
  description = "Enable backup for supported resources"
  type        = bool
  default     = true
}

# DNS Configuration
variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in VPC"
  type        = bool
  default     = true
}

# VPC Endpoints
variable "enable_vpc_endpoints" {
  description = "Enable VPC endpoints for AWS services"
  type        = bool
  default     = true
}

variable "vpc_endpoints" {
  description = "List of VPC endpoints to create"
  type = list(object({
    service_name    = string
    route_table_ids = list(string)
  }))
  default = []
}
