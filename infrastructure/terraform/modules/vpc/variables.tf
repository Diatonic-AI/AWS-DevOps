# VPC Module Variables

variable "name_prefix" {
  description = "Name prefix for all resources"
  type        = string
  validation {
    condition     = length(var.name_prefix) <= 20
    error_message = "Name prefix must be 20 characters or less."
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

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "az_count" {
  description = "Number of Availability Zones to use"
  type        = number
  default     = 2
  validation {
    condition     = var.az_count >= 2 && var.az_count <= 6
    error_message = "AZ count must be between 2 and 6."
  }
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "VPC Flow Logs retention in days"
  type        = number
  default     = 30
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653, 0
    ], var.flow_logs_retention_days)
    error_message = "Flow logs retention days must be a valid CloudWatch Logs retention period."
  }
}

variable "enable_vpc_endpoints" {
  description = "Enable VPC Endpoints for AWS services"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Cost optimization variables
variable "single_nat_gateway" {
  description = "Use a single NAT Gateway instead of one per AZ (cost optimization)"
  type        = bool
  default     = false
}

# Advanced networking options
variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in the VPC"
  type        = bool
  default     = true
}

variable "enable_classiclink" {
  description = "Enable ClassicLink for the VPC"
  type        = bool
  default     = false
}

variable "enable_classiclink_dns_support" {
  description = "Enable ClassicLink DNS Support for the VPC"
  type        = bool
  default     = false
}

# Network ACLs
variable "enable_custom_nacls" {
  description = "Enable custom Network ACLs (more restrictive than default)"
  type        = bool
  default     = false
}

# DHCP Options
variable "enable_dhcp_options" {
  description = "Enable DHCP options set"
  type        = bool
  default     = false
}

variable "dhcp_options_domain_name" {
  description = "Domain name for DHCP options"
  type        = string
  default     = ""
}

variable "dhcp_options_domain_name_servers" {
  description = "Domain name servers for DHCP options"
  type        = list(string)
  default     = ["AmazonProvidedDNS"]
}
