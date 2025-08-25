# ACM SSL Certificate Module Outputs

# Certificate Information
output "certificate_arn" {
  description = "ARN of the SSL certificate"
  value       = aws_acm_certificate.main.arn
}

output "certificate_id" {
  description = "ID of the SSL certificate"
  value       = aws_acm_certificate.main.id
}

output "certificate_status" {
  description = "Status of the SSL certificate"
  value       = aws_acm_certificate.main.status
}

output "certificate_domain_name" {
  description = "Domain name of the SSL certificate"
  value       = aws_acm_certificate.main.domain_name
}

output "certificate_subject_alternative_names" {
  description = "Subject alternative names of the SSL certificate"
  value       = aws_acm_certificate.main.subject_alternative_names
}

# Validation Information
output "domain_validation_options" {
  description = "Domain validation options for the certificate"
  value       = aws_acm_certificate.main.domain_validation_options
}

output "validation_records" {
  description = "DNS validation records"
  value = {
    for record in aws_route53_record.validation : record.name => {
      name    = record.name
      type    = record.type
      records = record.records
      ttl     = record.ttl
    }
  }
}

output "certificate_validation_arn" {
  description = "ARN of the validated certificate"
  value       = var.validation_method == "DNS" && var.route53_zone_id != null ? aws_acm_certificate_validation.main[0].certificate_arn : aws_acm_certificate.main.arn
}

# Certificate Details
output "certificate_not_before" {
  description = "Certificate validity start date"
  value       = aws_acm_certificate.main.not_before
}

output "certificate_not_after" {
  description = "Certificate validity end date"
  value       = aws_acm_certificate.main.not_after
}

output "certificate_type" {
  description = "Certificate type"
  value       = aws_acm_certificate.main.type
}

output "certificate_key_algorithm" {
  description = "Certificate key algorithm"
  value       = aws_acm_certificate.main.key_algorithm
}

# Monitoring
output "expiry_alarm_name" {
  description = "Name of the certificate expiry CloudWatch alarm"
  value       = var.enable_expiry_monitoring ? aws_cloudwatch_metric_alarm.certificate_expiry[0].alarm_name : null
}

output "renewal_event_rule_name" {
  description = "Name of the certificate renewal CloudWatch event rule"
  value       = var.enable_renewal_monitoring ? aws_cloudwatch_event_rule.certificate_renewal[0].name : null
}

# Configuration Summary
output "configuration_summary" {
  description = "SSL certificate configuration summary"
  value = {
    certificate_arn          = aws_acm_certificate.main.arn
    domain_name              = aws_acm_certificate.main.domain_name
    alternative_names        = aws_acm_certificate.main.subject_alternative_names
    validation_method        = var.validation_method
    key_algorithm            = var.key_algorithm
    status                   = aws_acm_certificate.main.status
    certificate_transparency = var.enable_certificate_transparency
    expiry_monitoring        = var.enable_expiry_monitoring
    renewal_monitoring       = var.enable_renewal_monitoring
    dns_validation           = var.validation_method == "DNS" && var.route53_zone_id != null
    auto_validated           = var.validation_method == "DNS" && var.route53_zone_id != null
  }
}

# Management URLs
output "management_urls" {
  description = "AWS Console URLs for certificate management"
  value = {
    certificate       = "https://console.aws.amazon.com/acm/home?region=${data.aws_region.current.name}#/certificates/${aws_acm_certificate.main.id}"
    cloudwatch_alarms = var.enable_expiry_monitoring ? "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#alarmsV2:alarm/${aws_cloudwatch_metric_alarm.certificate_expiry[0].alarm_name}" : null
  }
}

# Cost Information
output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown"
  value = {
    certificate    = "$0.75/month per certificate (after first year free)"
    monitoring     = var.enable_expiry_monitoring ? "~$0.30/month for CloudWatch alarms" : "$0.00"
    dns_validation = var.validation_method == "DNS" && var.route53_zone_id != null ? "Included in Route53 costs" : "N/A"
    total_estimate = var.enable_expiry_monitoring ? "~$1.05/month (after first year free)" : "~$0.75/month (after first year free)"
    notes = [
      "First year is free for ACM certificates",
      "Renewal is automatic and free",
      "CloudWatch alarms cost ~$0.10/month per alarm",
      "DNS validation uses Route53 queries (typically <$0.01/month)"
    ]
  }
}

# Data sources
data "aws_region" "current" {}
