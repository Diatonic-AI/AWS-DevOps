# CloudFront CDN Module Variables
# Global content delivery for web applications

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
}

# Domain Configuration
variable "domain_name" {
  description = "Primary domain name for the distribution"
  type        = string
  default     = null
}

variable "alternative_names" {
  description = "Alternative domain names (CNAMEs) for the distribution"
  type        = list(string)
  default     = []
}

# Origin Configuration
variable "s3_bucket_domain_name" {
  description = "S3 bucket domain name for static content origin"
  type        = string
  default     = null
}

variable "load_balancer_domain_name" {
  description = "Application Load Balancer domain name for dynamic content origin"
  type        = string
  default     = null
}

variable "custom_origin_domain_name" {
  description = "Custom origin domain name"
  type        = string
  default     = null
}

# SSL Configuration
variable "ssl_certificate_arn" {
  description = "ARN of SSL certificate from ACM (must be in us-east-1 for CloudFront)"
  type        = string
  default     = null
}

variable "ssl_support_method" {
  description = "SSL support method"
  type        = string
  default     = "sni-only"

  validation {
    condition     = contains(["sni-only", "vip", "static-ip"], var.ssl_support_method)
    error_message = "SSL support method must be one of: sni-only, vip, static-ip."
  }
}

variable "minimum_protocol_version" {
  description = "Minimum SSL/TLS protocol version"
  type        = string
  default     = "TLSv1.2_2021"
}

# Caching Configuration
variable "price_class" {
  description = "CloudFront price class for cost optimization"
  type        = string
  default     = "PriceClass_100" # Cheapest option

  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.price_class)
    error_message = "Price class must be one of: PriceClass_All, PriceClass_200, PriceClass_100."
  }
}

variable "default_ttl" {
  description = "Default TTL for cached objects (seconds)"
  type        = number
  default     = 86400 # 1 day
}

variable "max_ttl" {
  description = "Maximum TTL for cached objects (seconds)"
  type        = number
  default     = 31536000 # 1 year
}

variable "min_ttl" {
  description = "Minimum TTL for cached objects (seconds)"
  type        = number
  default     = 0
}

# Behavior Configuration
variable "allowed_methods" {
  description = "HTTP methods allowed for the default cache behavior"
  type        = list(string)
  default     = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
}

variable "cached_methods" {
  description = "HTTP methods to cache for the default cache behavior"
  type        = list(string)
  default     = ["GET", "HEAD"]
}

variable "compress" {
  description = "Enable compression for the distribution"
  type        = bool
  default     = true
}

variable "viewer_protocol_policy" {
  description = "Protocol policy for viewers"
  type        = string
  default     = "redirect-to-https"

  validation {
    condition     = contains(["allow-all", "https-only", "redirect-to-https"], var.viewer_protocol_policy)
    error_message = "Viewer protocol policy must be one of: allow-all, https-only, redirect-to-https."
  }
}

# Cache Behaviors for different content types
variable "cache_behaviors" {
  description = "Additional cache behaviors for specific paths"
  type = list(object({
    path_pattern           = string
    target_origin_id       = string
    allowed_methods        = list(string)
    cached_methods         = list(string)
    compress               = bool
    viewer_protocol_policy = string
    min_ttl                = number
    default_ttl            = number
    max_ttl                = number
    forward_query_string   = bool
    forward_headers        = list(string)
    forward_cookies        = string
  }))
  default = []
}

# Geographic Restrictions
variable "geo_restriction_type" {
  description = "Type of geographic restriction"
  type        = string
  default     = "none"

  validation {
    condition     = contains(["none", "blacklist", "whitelist"], var.geo_restriction_type)
    error_message = "Geo restriction type must be one of: none, blacklist, whitelist."
  }
}

variable "geo_restriction_locations" {
  description = "List of country codes for geographic restrictions"
  type        = list(string)
  default     = []
}

# Error Pages
variable "custom_error_responses" {
  description = "Custom error page configurations"
  type = list(object({
    error_code            = number
    response_code         = number
    response_page_path    = string
    error_caching_min_ttl = number
  }))
  default = []
}

# Logging
variable "enable_logging" {
  description = "Enable access logging"
  type        = bool
  default     = false # Disabled by default to save costs
}

variable "logging_bucket" {
  description = "S3 bucket for access logs"
  type        = string
  default     = null
}

variable "logging_prefix" {
  description = "Prefix for access log files"
  type        = string
  default     = "cloudfront-logs/"
}

variable "log_include_cookies" {
  description = "Include cookies in access logs"
  type        = bool
  default     = false
}

# WAF
variable "web_acl_id" {
  description = "AWS WAF web ACL ID to associate with the distribution"
  type        = string
  default     = null
}

# Real-time Monitoring
variable "enable_realtime_metrics" {
  description = "Enable real-time metrics (additional cost)"
  type        = bool
  default     = false
}

# Origin Shield
variable "enable_origin_shield" {
  description = "Enable Origin Shield for additional caching layer"
  type        = bool
  default     = false # Disabled to save costs
}

variable "origin_shield_region" {
  description = "AWS region for Origin Shield"
  type        = string
  default     = "us-east-1"
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
