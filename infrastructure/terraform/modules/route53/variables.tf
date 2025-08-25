# Route53 DNS Module Variables

variable "domain_name" {
  description = "Primary domain name to manage"
  type        = string
}

variable "create_zone" {
  description = "Create a new hosted zone for the domain"
  type        = bool
  default     = false
}

variable "zone_id" {
  description = "Existing Route53 hosted zone ID (required if create_zone is false)"
  type        = string
  default     = null
}

# CloudFront Integration
variable "cloudfront_distribution_domain_name" {
  description = "CloudFront distribution domain name"
  type        = string
  default     = null
}

variable "cloudfront_distribution_hosted_zone_id" {
  description = "CloudFront distribution hosted zone ID"
  type        = string
  default     = null
}

# Load Balancer Integration
variable "load_balancer_domain_name" {
  description = "Application Load Balancer domain name"
  type        = string
  default     = null
}

variable "load_balancer_hosted_zone_id" {
  description = "Application Load Balancer hosted zone ID"
  type        = string
  default     = null
}

# Certificate Validation
variable "certificate_validation_records" {
  description = "Certificate validation records for ACM"
  type = list(object({
    name  = string
    type  = string
    value = string
  }))
  default = []
}

# Subdomains
variable "subdomains" {
  description = "List of subdomains to create"
  type = list(object({
    name    = string
    type    = string
    ttl     = optional(number, 300)
    records = optional(list(string), [])
    alias = optional(object({
      name                   = string
      zone_id                = string
      evaluate_target_health = optional(bool, false)
    }), null)
  }))
  default = []
}

# Health Checks
variable "health_checks" {
  description = "Health check configurations"
  type = list(object({
    name                            = string
    type                            = string
    resource_path                   = optional(string, "/")
    failure_threshold               = optional(number, 3)
    request_interval                = optional(number, 30)
    fqdn                            = optional(string, null)
    ip_address                      = optional(string, null)
    port                            = optional(number, 80)
    search_string                   = optional(string, null)
    cloudwatch_alarm_region         = optional(string, "us-east-1")
    insufficient_data_health_status = optional(string, "LastKnownStatus")
    tags                            = optional(map(string), {})
  }))
  default = []
}

# MX Records for email
variable "mx_records" {
  description = "MX records for email routing"
  type = list(object({
    priority = number
    value    = string
  }))
  default = []
}

# SPF, DKIM, DMARC records
variable "txt_records" {
  description = "TXT records for domain verification and security"
  type = list(object({
    name  = string
    value = string
    ttl   = optional(number, 300)
  }))
  default = []
}

# CNAME Records
variable "cname_records" {
  description = "CNAME records for domain aliases"
  type = list(object({
    name  = string
    value = string
    ttl   = optional(number, 300)
  }))
  default = []
}

# Environment
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
