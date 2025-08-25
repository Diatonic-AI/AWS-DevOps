# CloudFront Module Outputs

# Distribution Information
output "distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.main.id
}

output "distribution_arn" {
  description = "ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.main.arn
}

output "distribution_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "distribution_hosted_zone_id" {
  description = "Hosted zone ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.main.hosted_zone_id
}

# Origin Access Identity
output "origin_access_identity_arn" {
  description = "ARN of the origin access identity"
  value       = var.s3_bucket_domain_name != null ? aws_cloudfront_origin_access_identity.main[0].iam_arn : null
}

output "origin_access_identity_path" {
  description = "CloudFront access identity path"
  value       = var.s3_bucket_domain_name != null ? aws_cloudfront_origin_access_identity.main[0].cloudfront_access_identity_path : null
}

# URLs
output "distribution_url" {
  description = "URL of the CloudFront distribution"
  value       = "https://${aws_cloudfront_distribution.main.domain_name}"
}

output "custom_domain_url" {
  description = "Custom domain URL (if configured)"
  value       = var.domain_name != null ? "https://${var.domain_name}" : null
}

# Monitoring
output "monitoring_dashboard_url" {
  description = "URL to CloudWatch monitoring dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=${var.name_prefix}-cloudfront"
}

# Configuration Summary
output "configuration_summary" {
  description = "CloudFront configuration summary"
  value = {
    distribution_id  = aws_cloudfront_distribution.main.id
    domain_name      = aws_cloudfront_distribution.main.domain_name
    custom_domain    = var.domain_name
    price_class      = var.price_class
    ssl_enabled      = var.ssl_certificate_arn != null
    origins_count    = length(keys(local.origins))
    cache_behaviors  = length(var.cache_behaviors)
    logging_enabled  = var.enable_logging
    origin_shield    = var.enable_origin_shield
    realtime_metrics = var.enable_realtime_metrics
    estimated_cost   = "~$1-10/month depending on traffic"
  }
}

# Cost Information
output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown"
  value = {
    base_distribution = "~$0.60/month minimum"
    data_transfer_out = "~$0.085-0.17/GB (varies by region)"
    requests          = "~$0.0075-0.016/10k requests"
    price_class       = var.price_class
    total_estimate    = "~$1-10/month for small sites, scales with traffic"
    optimization_notes = [
      "Using ${var.price_class} price class",
      "Compression enabled: ${var.compress}",
      "Origin Shield: ${var.enable_origin_shield ? "enabled" : "disabled"}",
      "Real-time metrics: ${var.enable_realtime_metrics ? "enabled (+$1/month)" : "disabled"}"
    ]
  }
}
