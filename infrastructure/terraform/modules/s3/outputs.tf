# S3 Module Outputs
# These outputs provide access to S3 bucket information for use by other modules and services

# Bucket Information
output "bucket_names" {
  description = "Map of bucket types to their actual bucket names"
  value       = local.bucket_names
}

output "bucket_ids" {
  description = "Map of bucket types to their bucket IDs"
  value = {
    for k, v in aws_s3_bucket.main : k => v.id
  }
}

output "bucket_arns" {
  description = "Map of bucket types to their bucket ARNs"
  value = {
    for k, v in aws_s3_bucket.main : k => v.arn
  }
}

output "bucket_domain_names" {
  description = "Map of bucket types to their domain names"
  value = {
    for k, v in aws_s3_bucket.main : k => v.bucket_domain_name
  }
}

output "bucket_regional_domain_names" {
  description = "Map of bucket types to their regional domain names"
  value = {
    for k, v in aws_s3_bucket.main : k => v.bucket_regional_domain_name
  }
}

# Specific Bucket Outputs
output "application_bucket_name" {
  description = "Name of the application data bucket"
  value       = lookup(local.bucket_names, "application", null)
}

output "application_bucket_arn" {
  description = "ARN of the application data bucket"
  value       = lookup(aws_s3_bucket.main, "application", null) != null ? aws_s3_bucket.main["application"].arn : null
}

output "backup_bucket_name" {
  description = "Name of the backup bucket"
  value       = lookup(local.bucket_names, "backup", null)
}

output "backup_bucket_arn" {
  description = "ARN of the backup bucket"
  value       = lookup(aws_s3_bucket.main, "backup", null) != null ? aws_s3_bucket.main["backup"].arn : null
}

output "logs_bucket_name" {
  description = "Name of the logs bucket"
  value       = lookup(local.bucket_names, "logs", null)
}

output "logs_bucket_arn" {
  description = "ARN of the logs bucket"
  value       = lookup(aws_s3_bucket.main, "logs", null) != null ? aws_s3_bucket.main["logs"].arn : null
}

output "static_assets_bucket_name" {
  description = "Name of the static assets bucket"
  value       = lookup(local.bucket_names, "static-assets", null)
}

output "static_assets_bucket_arn" {
  description = "ARN of the static assets bucket"
  value       = lookup(aws_s3_bucket.main, "static-assets", null) != null ? aws_s3_bucket.main["static-assets"].arn : null
}

output "static_assets_website_endpoint" {
  description = "Website endpoint of the static assets bucket"
  value       = length(aws_s3_bucket_website_configuration.static_assets) > 0 ? aws_s3_bucket_website_configuration.static_assets[0].website_endpoint : null
}

output "compliance_bucket_name" {
  description = "Name of the compliance bucket"
  value       = lookup(local.bucket_names, "compliance", null)
}

output "compliance_bucket_arn" {
  description = "ARN of the compliance bucket"
  value       = lookup(aws_s3_bucket.main, "compliance", null) != null ? aws_s3_bucket.main["compliance"].arn : null
}

output "data_lake_bucket_name" {
  description = "Name of the data lake bucket"
  value       = lookup(local.bucket_names, "data-lake", null)
}

output "data_lake_bucket_arn" {
  description = "ARN of the data lake bucket"
  value       = lookup(aws_s3_bucket.main, "data-lake", null) != null ? aws_s3_bucket.main["data-lake"].arn : null
}

# Replication Information
output "replica_bucket_names" {
  description = "Map of bucket types to their replica bucket names"
  value       = local.replication_bucket_names
}

output "replica_bucket_arns" {
  description = "Map of bucket types to their replica bucket ARNs"
  value = {
    for k, v in aws_s3_bucket.replica : k => v.arn
  }
}

# Security Information
output "kms_key_id" {
  description = "KMS key ID used for S3 encryption"
  value       = var.kms_key_id != null ? var.kms_key_id : (length(aws_kms_key.s3_key) > 0 ? aws_kms_key.s3_key[0].id : null)
}

output "kms_key_arn" {
  description = "KMS key ARN used for S3 encryption"
  value       = var.kms_key_id != null ? var.kms_key_id : (length(aws_kms_key.s3_key) > 0 ? aws_kms_key.s3_key[0].arn : null)
}

output "kms_key_alias" {
  description = "KMS key alias used for S3 encryption"
  value       = length(aws_kms_alias.s3_key_alias) > 0 ? aws_kms_alias.s3_key_alias[0].name : null
}

# IAM Information
output "replication_role_arn" {
  description = "ARN of the cross-region replication IAM role"
  value       = length(aws_iam_role.replication_role) > 0 ? aws_iam_role.replication_role[0].arn : null
}

# CloudWatch Information
output "cloudwatch_metric_names" {
  description = "Map of bucket types to their CloudWatch metric names"
  value = {
    for k, v in aws_s3_bucket_metric.main : k => v.name
  }
}

# Access Patterns
output "public_read_buckets" {
  description = "List of buckets that allow public read access"
  value       = var.public_read_buckets
}

# Configuration Summary
output "configuration_summary" {
  description = "Summary of S3 configuration settings"
  value = {
    versioning_enabled       = var.enable_versioning
    mfa_delete_enabled       = var.enable_mfa_delete
    encryption_enabled       = var.enable_server_side_encryption
    cross_region_replication = var.enable_cross_region_replication
    replication_region       = var.replication_destination_region
    access_logging_enabled   = var.enable_access_logging
    intelligent_tiering      = var.enable_intelligent_tiering
    metrics_enabled          = var.enable_metrics
    inventory_enabled        = var.enable_inventory
    event_notifications      = var.enable_event_notifications
    static_website_enabled   = var.enable_static_website
    environment              = var.environment
    created_buckets          = keys(local.bucket_names)
  }
}

# Integration Information
output "vpc_integration_info" {
  description = "VPC integration information for S3"
  value = {
    vpc_id                    = var.vpc_id
    vpc_endpoint_route_tables = var.vpc_endpoint_route_table_ids
    s3_service_name           = "com.amazonaws.${local.region}.s3"
    dynamodb_service_name     = "com.amazonaws.${local.region}.dynamodb"
  }
}

# Cost Optimization Information
output "cost_optimization_features" {
  description = "Enabled cost optimization features"
  value = {
    intelligent_tiering         = var.enable_intelligent_tiering
    lifecycle_rules_enabled     = [for k, v in var.lifecycle_rules : k if v.enabled]
    request_payer_configuration = var.request_payer
    inventory_for_cost_analysis = var.enable_inventory
  }
}

# Bucket Usage Guidelines
output "bucket_usage_guidelines" {
  description = "Guidelines for using different bucket types"
  value = {
    application   = "Store application data, user uploads, and dynamic content"
    backup        = "Store automated backups and snapshots with lifecycle management"
    logs          = "Centralized logging for all AWS services and applications"
    static-assets = "Static website content, images, CSS, JS files for CDN distribution"
    compliance    = "Long-term storage for audit trails and compliance data"
    data-lake     = "Raw data storage for analytics and machine learning workloads"
  }
}

# Security Best Practices Applied
output "security_features" {
  description = "Security features applied to the buckets"
  value = {
    public_access_blocked    = "All buckets except those explicitly configured for public access"
    ssl_only_access          = "All buckets require HTTPS/SSL connections"
    server_side_encryption   = var.enable_server_side_encryption ? "Enabled with KMS or AES256" : "Disabled"
    versioning               = var.enable_versioning ? "Enabled for data protection" : "Disabled"
    mfa_delete               = var.enable_mfa_delete ? "Enabled for critical operations" : "Disabled"
    cross_region_replication = var.enable_cross_region_replication ? "Enabled for disaster recovery" : "Disabled"
    access_logging           = var.enable_access_logging ? "Enabled for audit trails" : "Disabled"
    lifecycle_management     = "Automated transitions and cleanup policies"
    inventory_tracking       = var.enable_inventory ? "Daily inventory reports" : "Disabled"
    cors_configured          = length(var.cors_rules) > 0 ? "Configured for static assets" : "Not configured"
  }
}
