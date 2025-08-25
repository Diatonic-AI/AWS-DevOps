# CloudFront CDN Module - Global Content Delivery
# Cost-optimized global content delivery for web applications

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

  # Determine primary origin based on available inputs
  primary_origin = var.s3_bucket_domain_name != null ? "s3" : var.load_balancer_domain_name != null ? "alb" : "custom"

  # Origins configuration
  origins = merge(
    var.s3_bucket_domain_name != null ? {
      s3 = {
        domain_name = var.s3_bucket_domain_name
        origin_id   = "S3-${local.name_prefix}"
        s3_origin_config = {
          origin_access_identity = aws_cloudfront_origin_access_identity.main[0].cloudfront_access_identity_path
        }
      }
    } : {},
    var.load_balancer_domain_name != null ? {
      alb = {
        domain_name = var.load_balancer_domain_name
        origin_id   = "ALB-${local.name_prefix}"
        custom_origin_config = {
          http_port              = 80
          https_port             = 443
          origin_protocol_policy = "https-only"
          origin_ssl_protocols   = ["TLSv1.2"]
        }
      }
    } : {},
    var.custom_origin_domain_name != null ? {
      custom = {
        domain_name = var.custom_origin_domain_name
        origin_id   = "Custom-${local.name_prefix}"
        custom_origin_config = {
          http_port              = 80
          https_port             = 443
          origin_protocol_policy = "https-only"
          origin_ssl_protocols   = ["TLSv1.2"]
        }
      }
    } : {}
  )

  # Default cache behavior based on primary origin
  default_cache_behavior = {
    target_origin_id       = local.origins[local.primary_origin].origin_id
    viewer_protocol_policy = var.viewer_protocol_policy
    allowed_methods        = var.allowed_methods
    cached_methods         = var.cached_methods
    compress               = var.compress

    forwarded_values = {
      query_string = local.primary_origin == "s3" ? false : true
      cookies = {
        forward = local.primary_origin == "s3" ? "none" : "all"
      }
      headers = local.primary_origin == "s3" ? [] : ["Host", "CloudFront-Forwarded-Proto"]
    }

    min_ttl     = var.min_ttl
    default_ttl = local.primary_origin == "s3" ? var.default_ttl : 0
    max_ttl     = var.max_ttl
  }

  common_tags = merge(var.tags, {
    Module      = "cloudfront"
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

# Origin Access Identity for S3 (if using S3 origin)
resource "aws_cloudfront_origin_access_identity" "main" {
  count = var.s3_bucket_domain_name != null ? 1 : 0

  comment = "OAI for ${local.name_prefix} CloudFront distribution"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "main" {
  comment             = "${local.name_prefix} CDN distribution"
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = var.price_class
  web_acl_id          = var.web_acl_id

  # Alternative domain names
  aliases = var.domain_name != null ? concat([var.domain_name], var.alternative_names) : var.alternative_names

  # Origins
  dynamic "origin" {
    for_each = local.origins
    content {
      domain_name = origin.value.domain_name
      origin_id   = origin.value.origin_id

      # S3 origin configuration
      dynamic "s3_origin_config" {
        for_each = can(origin.value.s3_origin_config) ? [origin.value.s3_origin_config] : []
        content {
          origin_access_identity = s3_origin_config.value.origin_access_identity
        }
      }

      # Custom origin configuration
      dynamic "custom_origin_config" {
        for_each = can(origin.value.custom_origin_config) ? [origin.value.custom_origin_config] : []
        content {
          http_port              = custom_origin_config.value.http_port
          https_port             = custom_origin_config.value.https_port
          origin_protocol_policy = custom_origin_config.value.origin_protocol_policy
          origin_ssl_protocols   = custom_origin_config.value.origin_ssl_protocols
        }
      }

      # Origin Shield (if enabled)
      dynamic "origin_shield" {
        for_each = var.enable_origin_shield ? [1] : []
        content {
          enabled              = true
          origin_shield_region = var.origin_shield_region
        }
      }
    }
  }

  # Default cache behavior
  default_cache_behavior {
    allowed_methods        = local.default_cache_behavior.allowed_methods
    cached_methods         = local.default_cache_behavior.cached_methods
    target_origin_id       = local.default_cache_behavior.target_origin_id
    viewer_protocol_policy = local.default_cache_behavior.viewer_protocol_policy
    compress               = local.default_cache_behavior.compress

    forwarded_values {
      query_string = local.default_cache_behavior.forwarded_values.query_string
      headers      = local.default_cache_behavior.forwarded_values.headers

      cookies {
        forward = local.default_cache_behavior.forwarded_values.cookies.forward
      }
    }

    min_ttl     = local.default_cache_behavior.min_ttl
    default_ttl = local.default_cache_behavior.default_ttl
    max_ttl     = local.default_cache_behavior.max_ttl

    # Real-time metrics (additional cost)
    realtime_log_config_arn = var.enable_realtime_metrics ? aws_cloudwatch_log_group.realtime[0].arn : null
  }

  # Additional cache behaviors
  dynamic "ordered_cache_behavior" {
    for_each = var.cache_behaviors
    content {
      path_pattern           = ordered_cache_behavior.value.path_pattern
      allowed_methods        = ordered_cache_behavior.value.allowed_methods
      cached_methods         = ordered_cache_behavior.value.cached_methods
      target_origin_id       = ordered_cache_behavior.value.target_origin_id
      viewer_protocol_policy = ordered_cache_behavior.value.viewer_protocol_policy
      compress               = ordered_cache_behavior.value.compress

      forwarded_values {
        query_string = ordered_cache_behavior.value.forward_query_string
        headers      = ordered_cache_behavior.value.forward_headers

        cookies {
          forward = ordered_cache_behavior.value.forward_cookies
        }
      }

      min_ttl     = ordered_cache_behavior.value.min_ttl
      default_ttl = ordered_cache_behavior.value.default_ttl
      max_ttl     = ordered_cache_behavior.value.max_ttl
    }
  }

  # Geographic restrictions
  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type
      locations        = var.geo_restriction_locations
    }
  }

  # SSL configuration
  viewer_certificate {
    cloudfront_default_certificate = var.ssl_certificate_arn == null
    acm_certificate_arn            = var.ssl_certificate_arn
    ssl_support_method             = var.ssl_certificate_arn != null ? var.ssl_support_method : null
    minimum_protocol_version       = var.ssl_certificate_arn != null ? var.minimum_protocol_version : null
  }

  # Custom error responses
  dynamic "custom_error_response" {
    for_each = var.custom_error_responses
    content {
      error_code            = custom_error_response.value.error_code
      response_code         = custom_error_response.value.response_code
      response_page_path    = custom_error_response.value.response_page_path
      error_caching_min_ttl = custom_error_response.value.error_caching_min_ttl
    }
  }

  # Access logging
  dynamic "logging_config" {
    for_each = var.enable_logging && var.logging_bucket != null ? [1] : []
    content {
      bucket          = var.logging_bucket
      prefix          = var.logging_prefix
      include_cookies = var.log_include_cookies
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cloudfront-distribution"
    Type = "cloudfront_distribution"
  })
}

# CloudWatch Log Group for Real-time Logs (if enabled)
resource "aws_cloudwatch_log_group" "realtime" {
  count = var.enable_realtime_metrics ? 1 : 0

  name              = "/aws/cloudfront/realtime/${local.name_prefix}"
  retention_in_days = 7 # Keep costs low

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cloudfront-realtime-logs"
    Type = "log_group"
  })
}

# CloudWatch Alarms for monitoring (cost-optimized)
resource "aws_cloudwatch_metric_alarm" "high_4xx_rate" {
  alarm_name          = "${local.name_prefix}-cloudfront-high-4xx-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = "300"
  statistic           = "Average"
  threshold           = "5" # 5% 4xx error rate
  alarm_description   = "This metric monitors CloudFront 4xx error rate"

  dimensions = {
    DistributionId = aws_cloudfront_distribution.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cloudfront-4xx-alarm"
    Type = "cloudwatch_alarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "high_5xx_rate" {
  alarm_name          = "${local.name_prefix}-cloudfront-high-5xx-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = "300"
  statistic           = "Average"
  threshold           = "1" # 1% 5xx error rate
  alarm_description   = "This metric monitors CloudFront 5xx error rate"

  dimensions = {
    DistributionId = aws_cloudfront_distribution.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cloudfront-5xx-alarm"
    Type = "cloudwatch_alarm"
  })
}
