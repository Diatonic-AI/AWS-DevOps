# ACM SSL Certificate Module - SSL/TLS Certificate Management
# Automated SSL certificate provisioning and validation

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

  # Subject Alternative Names including wildcard
  subject_alternative_names = var.include_wildcard ? concat(var.subject_alternative_names, ["*.${local.root_domain}"]) : var.subject_alternative_names

  common_tags = merge(var.tags, {
    Module      = "acm"
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

# SSL Certificate
resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name
  subject_alternative_names = local.subject_alternative_names
  validation_method         = var.validation_method

  # Key algorithm
  key_algorithm = var.key_algorithm

  # Certificate options
  options {
    certificate_transparency_logging_preference = var.enable_certificate_transparency ? "ENABLED" : "DISABLED"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name   = "${local.name_prefix}-ssl-certificate"
    Type   = "ssl_certificate"
    Domain = var.domain_name
  })
}

# Certificate validation (DNS method)
resource "aws_acm_certificate_validation" "main" {
  count = var.validation_method == "DNS" && var.route53_zone_id != null ? 1 : 0

  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]

  timeouts {
    create = var.validation_timeout
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Route53 validation records (if DNS validation and zone provided)
resource "aws_route53_record" "validation" {
  for_each = var.validation_method == "DNS" && var.route53_zone_id != null ? {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

# CloudWatch metric for certificate expiry monitoring
resource "aws_cloudwatch_metric_alarm" "certificate_expiry" {
  count = var.enable_expiry_monitoring ? 1 : 0

  alarm_name          = "${local.name_prefix}-ssl-certificate-expiry"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DaysToExpiry"
  namespace           = "AWS/CertificateManager"
  period              = "86400" # Daily check
  statistic           = "Minimum"
  threshold           = "30" # Alert 30 days before expiry
  alarm_description   = "SSL certificate expires in less than 30 days"
  treat_missing_data  = "breaching"

  dimensions = {
    CertificateArn = aws_acm_certificate.main.arn
  }

  alarm_actions = var.notification_topic_arn != null ? [var.notification_topic_arn] : []

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ssl-expiry-alarm"
    Type = "cloudwatch_alarm"
  })
}

# Certificate renewal CloudWatch event (for monitoring)
resource "aws_cloudwatch_event_rule" "certificate_renewal" {
  count = var.enable_renewal_monitoring ? 1 : 0

  name        = "${local.name_prefix}-ssl-certificate-renewal"
  description = "Monitor SSL certificate renewal events"

  event_pattern = jsonencode({
    source      = ["aws.acm"]
    detail-type = ["ACM Certificate Approaching Expiration"]
    detail = {
      DaysToExpiry = [
        { "numeric" : ["<=", 30] }
      ]
    }
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ssl-renewal-rule"
    Type = "cloudwatch_event_rule"
  })
}

# Event target for certificate renewal notifications
resource "aws_cloudwatch_event_target" "certificate_renewal" {
  count = var.enable_renewal_monitoring && var.notification_topic_arn != null ? 1 : 0

  rule      = aws_cloudwatch_event_rule.certificate_renewal[0].name
  target_id = "SendToSNS"
  arn       = var.notification_topic_arn
}
