# Route53 DNS Module - Domain Name Management
# Advanced DNS management with health checks and routing policies

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Local values
locals {
  name_prefix = var.name_prefix

  # Domain configuration
  domain_parts = split(".", var.domain_name)
  root_domain  = length(local.domain_parts) > 2 ? join(".", slice(local.domain_parts, length(local.domain_parts) - 2, length(local.domain_parts))) : var.domain_name

  common_tags = merge(var.tags, {
    Module      = "route53"
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

# Data source for existing hosted zone (if not creating new one and zone_id is provided)
data "aws_route53_zone" "existing" {
  count = !var.create_zone && var.zone_id != null ? 1 : 0

  zone_id      = var.zone_id
  private_zone = false
}

# Create hosted zone (if requested)
resource "aws_route53_zone" "main" {
  count = var.create_zone ? 1 : 0

  name    = local.root_domain
  comment = "Managed by Terraform for ${var.name_prefix}"

  tags = merge(local.common_tags, {
    Name   = "${local.name_prefix}-hosted-zone"
    Type   = "hosted_zone"
    Domain = local.root_domain
  })
}

# Local reference to the hosted zone
locals {
  hosted_zone_id   = var.create_zone ? aws_route53_zone.main[0].zone_id : data.aws_route53_zone.existing[0].zone_id
  hosted_zone_name = var.create_zone ? aws_route53_zone.main[0].name : data.aws_route53_zone.existing[0].name
}

# A record for CloudFront distribution
resource "aws_route53_record" "cloudfront" {
  count = var.cloudfront_distribution_domain_name != null ? 1 : 0

  zone_id = local.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.cloudfront_distribution_domain_name
    zone_id                = var.cloudfront_distribution_hosted_zone_id
    evaluate_target_health = false
  }
}

# AAAA record for CloudFront distribution (IPv6)
resource "aws_route53_record" "cloudfront_ipv6" {
  count = var.cloudfront_distribution_domain_name != null ? 1 : 0

  zone_id = local.hosted_zone_id
  name    = var.domain_name
  type    = "AAAA"

  alias {
    name                   = var.cloudfront_distribution_domain_name
    zone_id                = var.cloudfront_distribution_hosted_zone_id
    evaluate_target_health = false
  }
}

# A record for Application Load Balancer
resource "aws_route53_record" "alb" {
  count = var.load_balancer_domain_name != null ? 1 : 0

  zone_id = local.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.load_balancer_domain_name
    zone_id                = var.load_balancer_hosted_zone_id
    evaluate_target_health = true
  }
}

# Certificate validation records
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in var.certificate_validation_records : dvo.name => {
      name  = dvo.name
      type  = dvo.type
      value = dvo.value
    }
  }

  zone_id = local.hosted_zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.value]
  ttl     = 60

  allow_overwrite = true
}

# Subdomain records
resource "aws_route53_record" "subdomains" {
  for_each = {
    for subdomain in var.subdomains : subdomain.name => subdomain
  }

  zone_id = local.hosted_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = each.value.ttl
  records = each.value.records

  # Alias configuration (if provided)
  dynamic "alias" {
    for_each = each.value.alias != null ? [each.value.alias] : []
    content {
      name                   = alias.value.name
      zone_id                = alias.value.zone_id
      evaluate_target_health = alias.value.evaluate_target_health
    }
  }
}

# MX records for email
resource "aws_route53_record" "mx" {
  count = length(var.mx_records) > 0 ? 1 : 0

  zone_id = local.hosted_zone_id
  name    = var.domain_name
  type    = "MX"
  ttl     = 300

  records = [
    for record in var.mx_records : "${record.priority} ${record.value}"
  ]
}

# TXT records (SPF, DKIM, DMARC, etc.)
resource "aws_route53_record" "txt" {
  for_each = {
    for record in var.txt_records : record.name => record
  }

  zone_id = local.hosted_zone_id
  name    = each.value.name
  type    = "TXT"
  ttl     = each.value.ttl
  records = [each.value.value]
}

# CNAME records
resource "aws_route53_record" "cname" {
  for_each = {
    for record in var.cname_records : record.name => record
  }

  zone_id = local.hosted_zone_id
  name    = each.value.name
  type    = "CNAME"
  ttl     = each.value.ttl
  records = [each.value.value]
}

# Health checks
resource "aws_route53_health_check" "main" {
  for_each = {
    for check in var.health_checks : check.name => check
  }

  fqdn                            = each.value.fqdn
  port                            = each.value.port
  type                            = each.value.type
  resource_path                   = each.value.resource_path
  failure_threshold               = each.value.failure_threshold
  request_interval                = each.value.request_interval
  search_string                   = each.value.search_string
  cloudwatch_alarm_region         = each.value.cloudwatch_alarm_region
  insufficient_data_health_status = each.value.insufficient_data_health_status

  tags = merge(local.common_tags, each.value.tags, {
    Name = "${local.name_prefix}-health-check-${each.key}"
    Type = "health_check"
  })
}

# CloudWatch alarms for domain monitoring
resource "aws_cloudwatch_metric_alarm" "domain_health" {
  count = length(var.health_checks) > 0 ? 1 : 0

  alarm_name          = "${local.name_prefix}-domain-health"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = "60"
  statistic           = "Minimum"
  threshold           = "1"
  alarm_description   = "This metric monitors domain health check status"
  treat_missing_data  = "breaching"

  dimensions = {
    HealthCheckId = values(aws_route53_health_check.main)[0].id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-domain-health-alarm"
    Type = "cloudwatch_alarm"
  })
}
