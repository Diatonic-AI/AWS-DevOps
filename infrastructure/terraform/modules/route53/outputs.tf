# Route53 Module Outputs

# Hosted Zone Information
output "hosted_zone_id" {
  description = "ID of the Route53 hosted zone"
  value       = local.hosted_zone_id
}

output "hosted_zone_name" {
  description = "Name of the Route53 hosted zone"
  value       = local.hosted_zone_name
}

output "hosted_zone_name_servers" {
  description = "Name servers for the hosted zone"
  value       = var.create_zone ? aws_route53_zone.main[0].name_servers : null
}

# DNS Records
output "domain_name" {
  description = "Primary domain name"
  value       = var.domain_name
}

output "cloudfront_record_name" {
  description = "CloudFront A record name"
  value       = var.cloudfront_distribution_domain_name != null ? aws_route53_record.cloudfront[0].name : null
}

output "alb_record_name" {
  description = "ALB A record name"
  value       = var.load_balancer_domain_name != null ? aws_route53_record.alb[0].name : null
}

# Certificate Validation
output "certificate_validation_records" {
  description = "Certificate validation DNS records"
  value = {
    for record in aws_route53_record.cert_validation : record.name => {
      name    = record.name
      type    = record.type
      records = record.records
    }
  }
}

# Health Checks
output "health_check_ids" {
  description = "IDs of health checks"
  value = {
    for name, check in aws_route53_health_check.main : name => check.id
  }
}

output "health_check_status_urls" {
  description = "URLs to monitor health check status"
  value = {
    for name, check in aws_route53_health_check.main : name =>
    "https://console.aws.amazon.com/route53/healthchecks/home#/details/${check.id}"
  }
}

# Subdomain Information
output "subdomain_records" {
  description = "Information about subdomain records"
  value = {
    for name, record in aws_route53_record.subdomains : name => {
      name    = record.name
      type    = record.type
      records = record.records
      ttl     = record.ttl
    }
  }
}

# Email Configuration
output "mx_record" {
  description = "MX record configuration"
  value = length(var.mx_records) > 0 ? {
    name    = aws_route53_record.mx[0].name
    type    = aws_route53_record.mx[0].type
    records = aws_route53_record.mx[0].records
  } : null
}

output "txt_records" {
  description = "TXT records configuration"
  value = {
    for name, record in aws_route53_record.txt : name => {
      name    = record.name
      type    = record.type
      records = record.records
    }
  }
}

# Configuration Summary
output "configuration_summary" {
  description = "Route53 configuration summary"
  value = {
    hosted_zone_id         = local.hosted_zone_id
    domain_name            = var.domain_name
    zone_created           = var.create_zone
    cloudfront_enabled     = var.cloudfront_distribution_domain_name != null
    alb_enabled            = var.load_balancer_domain_name != null
    health_checks          = length(var.health_checks)
    subdomains             = length(var.subdomains)
    mx_records             = length(var.mx_records)
    txt_records            = length(var.txt_records)
    cname_records          = length(var.cname_records)
    certificate_validation = length(var.certificate_validation_records)
  }
}

# Cost Information
output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown"
  value = {
    hosted_zone         = var.create_zone ? "$0.50/month per hosted zone" : "$0.00 (using existing zone)"
    queries             = "$0.40 per million queries (first 1 billion queries/month)"
    health_checks       = length(var.health_checks) > 0 ? "${length(var.health_checks)} × $0.50 = $${length(var.health_checks) * 0.5}/month" : "$0.00"
    total_base_estimate = var.create_zone ? "$${0.5 + (length(var.health_checks) * 0.5)}/month" : "$${length(var.health_checks) * 0.5}/month"
    notes = [
      "DNS queries are typically very low cost",
      "Health checks are $0.50/month each",
      "Geolocation routing adds $0.70/month per resource record",
      "Latency-based routing adds $0.60/month per resource record"
    ]
  }
}

# DNS Management URLs
output "management_urls" {
  description = "AWS Console URLs for DNS management"
  value = {
    hosted_zone      = "https://console.aws.amazon.com/route53/v2/hostedzones#ListRecordSets/${local.hosted_zone_id}"
    health_checks    = length(var.health_checks) > 0 ? "https://console.aws.amazon.com/route53/healthchecks/home" : null
    traffic_policies = "https://console.aws.amazon.com/route53/trafficflow/home"
  }
}
