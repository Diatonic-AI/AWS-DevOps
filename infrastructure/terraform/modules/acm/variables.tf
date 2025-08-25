# ACM SSL Certificate Module Variables

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
  description = "Primary domain name for the certificate"
  type        = string
}

variable "subject_alternative_names" {
  description = "Additional domain names for the certificate"
  type        = list(string)
  default     = []
}

variable "include_wildcard" {
  description = "Include wildcard certificate for subdomains"
  type        = bool
  default     = true
}

# Certificate Configuration
variable "validation_method" {
  description = "Validation method for the certificate"
  type        = string
  default     = "DNS"

  validation {
    condition     = contains(["DNS", "EMAIL"], var.validation_method)
    error_message = "Validation method must be DNS or EMAIL."
  }
}

variable "key_algorithm" {
  description = "Key algorithm for the certificate"
  type        = string
  default     = "RSA_2048"

  validation {
    condition     = contains(["RSA_1024", "RSA_2048", "RSA_4096", "EC_prime256v1", "EC_secp384r1"], var.key_algorithm)
    error_message = "Key algorithm must be one of: RSA_1024, RSA_2048, RSA_4096, EC_prime256v1, EC_secp384r1."
  }
}

variable "enable_certificate_transparency" {
  description = "Enable certificate transparency logging"
  type        = bool
  default     = true
}

# DNS Validation
variable "route53_zone_id" {
  description = "Route53 hosted zone ID for DNS validation"
  type        = string
  default     = null
}

variable "validation_timeout" {
  description = "Timeout for certificate validation"
  type        = string
  default     = "5m"
}

# Monitoring
variable "enable_expiry_monitoring" {
  description = "Enable certificate expiry monitoring"
  type        = bool
  default     = true
}

variable "enable_renewal_monitoring" {
  description = "Enable certificate renewal monitoring"
  type        = bool
  default     = true
}

variable "notification_topic_arn" {
  description = "SNS topic ARN for certificate notifications"
  type        = string
  default     = null
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
