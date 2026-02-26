# Cloudflare DNS and CDN Module
# Manages diatonic.ai domain with Cloudflare DNS and performance features

terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# Data source for the zone (zone should already exist)
data "cloudflare_zone" "main" {
  zone_id = var.cloudflare_zone_id
}

# DNS Records - Production Environment (existing CloudFront)
# Apex domain - Import existing record
resource "cloudflare_record" "apex" {
  zone_id         = var.cloudflare_zone_id
  name            = var.domain_name
  value           = var.cloudfront_domain # d1bw1xopa9byqn.cloudfront.net (production)
  type            = "CNAME"
  proxied         = true
  ttl             = 1
  comment         = "Production apex domain - existing CloudFront"
  allow_overwrite = true
}

# WWW subdomain - Import existing record
resource "cloudflare_record" "www" {
  zone_id         = var.cloudflare_zone_id
  name            = "www"
  value           = var.cloudfront_domain # d1bw1xopa9byqn.cloudfront.net (production)
  type            = "CNAME"
  proxied         = true
  ttl             = 1
  comment         = "Production www subdomain"
  allow_overwrite = true
}

# App subdomain - Import existing record  
resource "cloudflare_record" "app" {
  zone_id         = var.cloudflare_zone_id
  name            = "app"
  value           = var.cloudfront_domain # d1bw1xopa9byqn.cloudfront.net (production)
  type            = "CNAME"
  proxied         = true
  ttl             = 1
  comment         = "Production app subdomain"
  allow_overwrite = true
}

# API subdomain for production
resource "cloudflare_record" "api_prod" {
  zone_id         = var.cloudflare_zone_id
  name            = "api"
  value           = var.cloudfront_domain # d1bw1xopa9byqn.cloudfront.net (production)
  type            = "CNAME"
  proxied         = true
  ttl             = 1
  allow_overwrite = true
  comment         = "Production API subdomain"
}

# Development Environment - Local Dev/Testing (new CloudFront)
resource "cloudflare_record" "local_dev" {
  zone_id = var.cloudflare_zone_id
  name    = "local.dev"
  value   = var.dev_cloudfront_domain # d34iz6fjitwuax.cloudfront.net (dev/testing)
  type    = "CNAME"
  proxied = true
  ttl     = 1
  comment = "Local development environment"
}

resource "cloudflare_record" "api_dev" {
  zone_id         = var.cloudflare_zone_id
  name            = "api.dev"
  value           = var.dev_cloudfront_domain # d34iz6fjitwuax.cloudfront.net (dev/testing)
  type            = "CNAME"
  proxied         = true
  ttl             = 1
  allow_overwrite = true
  comment         = "Development API subdomain"
}

resource "cloudflare_record" "app_dev" {
  zone_id         = var.cloudflare_zone_id
  name            = "app.dev"
  value           = var.dev_cloudfront_domain # d34iz6fjitwuax.cloudfront.net (dev/testing)
  type            = "CNAME"
  proxied         = true
  ttl             = 1
  comment         = "Development app subdomain"
  allow_overwrite = true # Import existing
}

resource "cloudflare_record" "www_dev" {
  zone_id         = var.cloudflare_zone_id
  name            = "www.dev"
  value           = var.dev_cloudfront_domain # d34iz6fjitwuax.cloudfront.net (dev/testing)
  type            = "CNAME"
  proxied         = true
  ttl             = 1
  comment         = "Development www subdomain"
  allow_overwrite = true # Import existing
}

# Keep existing dev.diatonic.ai pointing to current CloudFront (production)
resource "cloudflare_record" "dev" {
  zone_id         = var.cloudflare_zone_id
  name            = "dev"
  value           = var.cloudfront_domain # d1bw1xopa9byqn.cloudfront.net (keep existing)
  type            = "CNAME"
  proxied         = true
  ttl             = 1
  comment         = "Existing dev subdomain (production CloudFront)"
  allow_overwrite = true # Import existing
}

# API subdomain (DNS only for AWS ACM validation)
resource "cloudflare_record" "api" {
  count = var.api_domain != null ? 1 : 0
  
  zone_id = var.cloudflare_zone_id
  name    = "api"
  value   = var.api_domain != null ? var.api_domain : var.cloudfront_domain
  type    = "CNAME"
  proxied = false # DNS Only for ACM validation
  ttl     = 300
  comment = "API subdomain - DNS only for AWS ACM"
}

# Zone Settings Override - Full SSL, security, and performance control
resource "cloudflare_zone_settings_override" "main" {
  zone_id = var.cloudflare_zone_id

  settings {
    # SSL/TLS Settings
    ssl                       = var.ssl_mode
    always_use_https         = "on"
    min_tls_version          = "1.2"
    automatic_https_rewrites = "on"
    universal_ssl            = "on"

    # Security Settings
    security_level       = var.security_level
    browser_check        = "on"
    hotlink_protection   = "off"
    email_obfuscation    = "on"
    server_side_exclude  = "on"

    # Performance Settings
    brotli = "on"
    minify {
      css  = "on"
      html = "on"
      js   = "on"
    }
    rocket_loader       = var.enable_rocket_loader ? "on" : "off"
    cache_level         = var.cache_level
    browser_cache_ttl   = var.browser_cache_ttl
    
    # Development settings
    development_mode = var.development_mode ? "on" : "off"
    
    # IPv6 & HTTP settings
    ipv6 = "on"
    http2 = "on"
    http3 = "on"
    
    # Always Online
    always_online = "on"
  }
}

# Page Rules for enhanced caching and performance
resource "cloudflare_page_rule" "cache_everything_static" {
  zone_id  = var.cloudflare_zone_id
  target   = "*.${var.domain_name}/*.{css,js,png,jpg,jpeg,gif,ico,svg,woff,woff2,ttf,eot,webp,avif}"
  priority = 1
  status   = "active"

  actions {
    cache_level       = "cache_everything"
    edge_cache_ttl    = var.static_cache_ttl
    browser_cache_ttl = var.static_browser_cache_ttl
  }
}

resource "cloudflare_page_rule" "cache_api_bypass" {
  count = var.api_domain != null ? 1 : 0
  
  zone_id  = var.cloudflare_zone_id
  target   = "api.${var.domain_name}/*"
  priority = 2
  status   = "active"

  actions {
    cache_level = "bypass"
  }
}

# Security Rules - Bot protection and rate limiting
resource "cloudflare_filter" "block_bad_bots" {
  count = var.enable_bot_protection ? 1 : 0
  
  zone_id     = var.cloudflare_zone_id
  description = "Block known bad bots"
  expression  = "(cf.bot_management.score lt 30) and not (cf.bot_management.verified_bot)"
}

resource "cloudflare_firewall_rule" "block_bad_bots" {
  count = var.enable_bot_protection ? 1 : 0
  
  zone_id     = var.cloudflare_zone_id
  description = "Block requests from bad bots"
  filter_id   = cloudflare_filter.block_bad_bots[0].id
  action      = "block"
  priority    = 1000
}

# Rate Limiting (Free plan allows 1 rate limit rule)
resource "cloudflare_rate_limit" "api_protection" {
  count = var.enable_rate_limiting && var.api_domain != null ? 1 : 0
  
  zone_id   = var.cloudflare_zone_id
  threshold = var.rate_limit_threshold
  period    = 60
  
  match {
    request {
      url_pattern = "api.${var.domain_name}/*"
      schemes     = ["HTTP", "HTTPS"]
      methods     = ["GET", "POST", "PUT", "DELETE", "PATCH"]
    }
  }
  
  action {
    mode    = "challenge"
    timeout = 60
  }
  
  correlate {
    by = "nat"
  }
  
  disabled = false
  description = "Rate limit API endpoints"
}
