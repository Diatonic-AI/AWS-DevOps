# Unified Terraform Configuration Outputs

# Current workspace and environment information
output "workspace" {
  description = "Current Terraform workspace"
  value       = terraform.workspace
}

output "environment" {
  description = "Current environment"
  value       = local.environment
}

output "region" {
  description = "Current AWS region"
  value       = local.region
}

output "account_id" {
  description = "Current AWS account ID"
  value       = local.account_id
}

# Core Infrastructure Outputs (when enabled)
output "vpc_id" {
  description = "VPC ID from core infrastructure"
  value       = local.applications.core.enabled ? module.core_infrastructure[0].vpc_id : null
}

output "vpc_cidr_block" {
  description = "VPC CIDR block from core infrastructure"
  value       = local.applications.core.enabled ? module.core_infrastructure[0].vpc_cidr_block : null
}

output "public_subnet_ids" {
  description = "Public subnet IDs from core infrastructure"
  value       = local.applications.core.enabled ? module.core_infrastructure[0].public_subnet_ids : []
}

output "private_subnet_ids" {
  description = "Private subnet IDs from core infrastructure"
  value       = local.applications.core.enabled ? module.core_infrastructure[0].private_subnet_ids : []
}

output "data_subnet_ids" {
  description = "Data subnet IDs from core infrastructure"
  value       = local.applications.core.enabled ? module.core_infrastructure[0].data_subnet_ids : []
}

# AI Nexus Workbench Outputs (when enabled)
output "ai_nexus_bucket_id" {
  description = "AI Nexus S3 bucket ID"
  value       = local.applications.ai_nexus.enabled ? module.ai_nexus_workbench[0].ai_nexus_bucket_id : null
}

output "ai_nexus_bucket_arn" {
  description = "AI Nexus S3 bucket ARN"
  value       = local.applications.ai_nexus.enabled ? module.ai_nexus_workbench[0].ai_nexus_bucket_arn : null
}

# MinIO Infrastructure Outputs (when enabled)
output "minio_bucket_id" {
  description = "MinIO S3 bucket ID"
  value       = local.applications.minio.enabled ? module.minio_infrastructure[0].minio_bucket_id : null
}

output "minio_bucket_arn" {
  description = "MinIO S3 bucket ARN"
  value       = local.applications.minio.enabled ? module.minio_infrastructure[0].minio_bucket_arn : null
}

# Diatonic CloudFront Distribution Outputs (when enabled)
output "diatonic_cloudfront_distribution_id" {
  description = "Diatonic CloudFront distribution ID"
  value       = contains(["prod", "dev"], terraform.workspace) ? module.diatonic_cloudfront[0].distribution_id : null
}

output "diatonic_cloudfront_distribution_arn" {
  description = "Diatonic CloudFront distribution ARN"
  value       = contains(["prod", "dev"], terraform.workspace) ? module.diatonic_cloudfront[0].distribution_arn : null
}

output "diatonic_cloudfront_domain_name" {
  description = "Diatonic CloudFront distribution domain name"
  value       = contains(["prod", "dev"], terraform.workspace) ? module.diatonic_cloudfront[0].distribution_domain_name : null
}

output "diatonic_cloudfront_hosted_zone_id" {
  description = "Diatonic CloudFront distribution hosted zone ID"
  value       = contains(["prod", "dev"], terraform.workspace) ? module.diatonic_cloudfront[0].distribution_hosted_zone_id : null
}

output "diatonic_spa_function_arn" {
  description = "CloudFront Function ARN for Diatonic SPA routing"
  value       = contains(["prod", "dev"], terraform.workspace) ? module.diatonic_cloudfront[0].cloudfront_function_arn : null
}

# Application configuration summary
output "enabled_applications" {
  description = "List of enabled applications in current workspace"
  value = [
    for app, config in local.applications : app if config.enabled
  ]
}

output "environment_config_summary" {
  description = "Summary of current environment configuration"
  value = {
    vpc_cidr            = local.current_env_config.vpc_cidr
    nat_gateway_count   = local.current_env_config.nat_gateway_count
    enable_nat_instance = local.current_env_config.enable_nat_instance
    enable_flow_logs    = local.current_env_config.enable_flow_logs
    enable_backup       = local.current_env_config.enable_backup
    min_capacity        = local.current_env_config.min_capacity
    max_capacity        = local.current_env_config.max_capacity
    desired_capacity    = local.current_env_config.desired_capacity
  }
}

# Resource naming information
output "name_prefix" {
  description = "Resource name prefix used in current deployment"
  value       = local.name_prefix
}

output "unique_suffix" {
  description = "Unique suffix used for resource names"
  value       = local.unique_suffix
}

# Common tags applied to resources
output "common_tags" {
  description = "Common tags applied to all resources"
  value       = local.common_tags
  sensitive   = false
}

# Cloudflare Outputs (when enabled)
output "cloudflare_zone_id" {
  description = "Cloudflare Zone ID"
  value       = local.applications.cloudflare.enabled ? module.cloudflare[0].zone_id : null
}

output "cloudflare_nameservers" {
  description = "Cloudflare nameservers"
  value       = local.applications.cloudflare.enabled ? module.cloudflare[0].nameservers : null
}

output "cloudflare_dns_records" {
  description = "Cloudflare DNS records"
  value       = local.applications.cloudflare.enabled ? module.cloudflare[0].dns_records : null
}

output "cloudflare_ssl_status" {
  description = "Cloudflare SSL/TLS configuration"
  value       = local.applications.cloudflare.enabled ? module.cloudflare[0].ssl_status : null
}

output "cloudflare_performance_settings" {
  description = "Cloudflare performance configuration"
  value       = local.applications.cloudflare.enabled ? module.cloudflare[0].performance_settings : null
}

output "cloudflare_dashboard_urls" {
  description = "Cloudflare dashboard URLs for monitoring"
  value       = local.applications.cloudflare.enabled ? module.cloudflare[0].cloudflare_dashboard_urls : null
}

# Migration guidance output
output "dns_migration_instructions" {
  description = "Instructions for completing DNS migration to Cloudflare"
  value = local.applications.cloudflare.enabled ? {
    step_1 = "✅ DNS records configured in Cloudflare"
    step_2 = "🔄 Update nameservers at your domain registrar:"
    current_nameservers = [
      "ns-1632.awsdns-12.co.uk",
      "ns-710.awsdns-24.net", 
      "ns-1432.awsdns-51.org",
      "ns-45.awsdns-05.com"
    ]
    new_nameservers = local.applications.cloudflare.enabled ? module.cloudflare[0].nameservers : null
    step_3 = "⏱️ Wait 24-48 hours for full DNS propagation"
    step_4 = "🧪 Test with: dig diatonic.ai @1.1.1.1"
    step_5 = "📊 Monitor performance at: https://dash.cloudflare.com"
  } : null
}
