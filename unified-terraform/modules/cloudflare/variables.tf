# Cloudflare Module Variables

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for the domain"
  type        = string
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Primary domain name (e.g., diatonic.ai)"
  type        = string
}

variable "cloudfront_domain" {
  description = "CloudFront distribution domain for the apex domain (production)"
  type        = string
}

variable "dev_cloudfront_domain" {
  description = "CloudFront distribution domain for dev/testing environment"
  type        = string
}

variable "api_domain" {
  description = "API Gateway custom domain name (optional)"
  type        = string
  default     = null
}

# SSL/TLS Configuration
variable "ssl_mode" {
  description = "SSL/TLS encryption mode"
  type        = string
  default     = "full"
  validation {
    condition = contains([
      "off", "flexible", "full", "strict"
    ], var.ssl_mode)
    error_message = "SSL mode must be: off, flexible, full, or strict."
  }
}

# Security Configuration
variable "security_level" {
  description = "Security level for the zone"
  type        = string
  default     = "medium"
  validation {
    condition = contains([
      "essentially_off", "low", "medium", "high", "under_attack"
    ], var.security_level)
    error_message = "Security level must be: essentially_off, low, medium, high, or under_attack."
  }
}

variable "enable_bot_protection" {
  description = "Enable bot protection rules"
  type        = bool
  default     = true
}

variable "enable_rate_limiting" {
  description = "Enable rate limiting for API endpoints"
  type        = bool
  default     = true
}

variable "rate_limit_threshold" {
  description = "Rate limit threshold (requests per minute)"
  type        = number
  default     = 100
}

# Performance Configuration
variable "cache_level" {
  description = "Cache level for the zone"
  type        = string
  default     = "aggressive"
  validation {
    condition = contains([
      "aggressive", "basic", "simplified"
    ], var.cache_level)
    error_message = "Cache level must be: aggressive, basic, or simplified."
  }
}

variable "browser_cache_ttl" {
  description = "Browser cache TTL in seconds"
  type        = number
  default     = 14400 # 4 hours
}

variable "enable_rocket_loader" {
  description = "Enable Rocket Loader for JavaScript optimization"
  type        = bool
  default     = true
}

variable "development_mode" {
  description = "Enable development mode (bypasses cache)"
  type        = bool
  default     = false
}

# Static Assets Caching
variable "static_cache_ttl" {
  description = "Edge cache TTL for static assets (seconds)"
  type        = number
  default     = 2592000 # 30 days
}

variable "static_browser_cache_ttl" {
  description = "Browser cache TTL for static assets (seconds)"
  type        = number
  default     = 86400 # 24 hours
}

# Environment Configuration
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
