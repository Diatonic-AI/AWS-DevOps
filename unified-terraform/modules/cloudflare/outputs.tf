# Cloudflare Module Outputs

output "zone_id" {
  description = "Cloudflare Zone ID"
  value       = var.cloudflare_zone_id
}

output "zone_name" {
  description = "Zone name from data source"
  value       = data.cloudflare_zone.main.name
}

output "nameservers" {
  description = "Cloudflare nameservers"
  value       = data.cloudflare_zone.main.name_servers
}

output "dns_records" {
  description = "Created DNS records"
  value = {
    apex      = cloudflare_record.apex.hostname
    www       = cloudflare_record.www.hostname
    app       = cloudflare_record.app.hostname
    api_prod  = cloudflare_record.api_prod.hostname
    dev       = cloudflare_record.dev.hostname
    local_dev = cloudflare_record.local_dev.hostname
    api_dev   = cloudflare_record.api_dev.hostname
    app_dev   = cloudflare_record.app_dev.hostname
    www_dev   = cloudflare_record.www_dev.hostname
    api       = length(cloudflare_record.api) > 0 ? cloudflare_record.api[0].hostname : null
  }
}

output "dns_record_ids" {
  description = "Cloudflare DNS record IDs"
  value = {
    apex      = cloudflare_record.apex.id
    www       = cloudflare_record.www.id
    app       = cloudflare_record.app.id
    api_prod  = cloudflare_record.api_prod.id
    dev       = cloudflare_record.dev.id
    local_dev = cloudflare_record.local_dev.id
    api_dev   = cloudflare_record.api_dev.id
    app_dev   = cloudflare_record.app_dev.id
    www_dev   = cloudflare_record.www_dev.id
    api       = length(cloudflare_record.api) > 0 ? cloudflare_record.api[0].id : null
  }
}

output "ssl_status" {
  description = "SSL/TLS configuration status"
  value = {
    ssl_mode                 = cloudflare_zone_settings_override.main.settings[0].ssl
    always_use_https        = cloudflare_zone_settings_override.main.settings[0].always_use_https
    min_tls_version         = cloudflare_zone_settings_override.main.settings[0].min_tls_version
    automatic_https_rewrites = cloudflare_zone_settings_override.main.settings[0].automatic_https_rewrites
    universal_ssl           = cloudflare_zone_settings_override.main.settings[0].universal_ssl
  }
}

output "performance_settings" {
  description = "Performance and caching configuration"
  value = {
    cache_level         = cloudflare_zone_settings_override.main.settings[0].cache_level
    browser_cache_ttl   = cloudflare_zone_settings_override.main.settings[0].browser_cache_ttl
    brotli             = cloudflare_zone_settings_override.main.settings[0].brotli
    rocket_loader      = cloudflare_zone_settings_override.main.settings[0].rocket_loader
    development_mode   = cloudflare_zone_settings_override.main.settings[0].development_mode
  }
}

output "security_settings" {
  description = "Security configuration status"
  value = {
    security_level         = cloudflare_zone_settings_override.main.settings[0].security_level
    browser_check         = cloudflare_zone_settings_override.main.settings[0].browser_check
    email_obfuscation     = cloudflare_zone_settings_override.main.settings[0].email_obfuscation
    server_side_exclude   = cloudflare_zone_settings_override.main.settings[0].server_side_exclude
    bot_protection_enabled = length(cloudflare_firewall_rule.block_bad_bots) > 0
    rate_limiting_enabled  = length(cloudflare_rate_limit.api_protection) > 0
  }
}

output "page_rules" {
  description = "Created page rules"
  value = {
    static_cache_rule = cloudflare_page_rule.cache_everything_static.id
    api_bypass_rule   = length(cloudflare_page_rule.cache_api_bypass) > 0 ? cloudflare_page_rule.cache_api_bypass[0].id : null
  }
}

# Analytics and monitoring URLs
output "cloudflare_dashboard_urls" {
  description = "Cloudflare dashboard URLs for monitoring"
  value = {
    overview    = "https://dash.cloudflare.com/${var.cloudflare_zone_id}"
    dns         = "https://dash.cloudflare.com/${var.cloudflare_zone_id}/dns"
    ssl_tls     = "https://dash.cloudflare.com/${var.cloudflare_zone_id}/ssl-tls"
    speed       = "https://dash.cloudflare.com/${var.cloudflare_zone_id}/speed"
    caching     = "https://dash.cloudflare.com/${var.cloudflare_zone_id}/caching"
    page_rules  = "https://dash.cloudflare.com/${var.cloudflare_zone_id}/page-rules"
    firewall    = "https://dash.cloudflare.com/${var.cloudflare_zone_id}/security/waf"
    analytics   = "https://dash.cloudflare.com/${var.cloudflare_zone_id}/analytics"
  }
}
