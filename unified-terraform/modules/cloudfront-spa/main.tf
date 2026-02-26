# CloudFront SPA Distribution Module
# Properly configured for Single Page Applications with static asset handling

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Origin Access Identity for S3
resource "aws_cloudfront_origin_access_identity" "spa" {
  comment = "Origin access identity for ${var.domain_name}"
}

# CloudFront Function for SPA routing (viewer request)
resource "aws_cloudfront_function" "spa_routing" {
  name    = "${var.name_prefix}-spa-routing"
  runtime = "cloudfront-js-1.0"
  comment = "Safe SPA routing - only rewrite clean routes without file extensions"
  publish = true
  code    = file("${path.module}/cloudfront-function.js")
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "spa" {
  comment             = "SPA distribution for ${var.domain_name}"
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = var.price_class
  web_acl_id          = var.web_acl_id

  # Aliases (domain names)
  aliases = var.domain_names

  # S3 Origin
  origin {
    domain_name = var.s3_bucket_domain_name
    origin_id   = "S3-${var.s3_bucket_name}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.spa.cloudfront_access_identity_path
    }

    # Custom headers if needed
    dynamic "custom_header" {
      for_each = var.origin_custom_headers
      content {
        name  = custom_header.value.name
        value = custom_header.value.value
      }
    }
  }

  # Static Assets Behavior (High Priority - No SPA routing)
  ordered_cache_behavior {
    path_pattern     = "/assets/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.s3_bucket_name}"
    
    # No SPA routing function attached!
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    # Long-term caching for hashed assets
    min_ttl     = 31536000  # 1 year
    default_ttl = 31536000  # 1 year
    max_ttl     = 31536000  # 1 year

    # Response headers policy for assets
    response_headers_policy_id = aws_cloudfront_response_headers_policy.assets.id
  }

  # Static files behavior
  ordered_cache_behavior {
    path_pattern     = "/static/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.s3_bucket_name}"
    
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 31536000
    default_ttl = 31536000
    max_ttl     = 31536000

    response_headers_policy_id = aws_cloudfront_response_headers_policy.assets.id
  }

  # Favicon and common files
  ordered_cache_behavior {
    path_pattern     = "/*.ico"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.s3_bucket_name}"
    
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 86400   # 1 day
    default_ttl = 86400   # 1 day
    max_ttl     = 31536000 # 1 year
  }

  # Manifest and other common files
  ordered_cache_behavior {
    path_pattern     = "/*.json"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.s3_bucket_name}"
    
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 3600    # 1 hour
    default_ttl = 86400   # 1 day
    max_ttl     = 86400   # 1 day
  }

  # Default behavior for SPA routes and HTML
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.s3_bucket_name}"
    
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    # Attach SPA routing function
    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.spa_routing.arn
    }

    forwarded_values {
      query_string = false
      headers      = ["Origin", "Access-Control-Request-Headers", "Access-Control-Request-Method"]
      
      cookies {
        forward = "none"
      }
    }

    # Short caching for HTML and SPA routes
    min_ttl     = 0
    default_ttl = 300     # 5 minutes
    max_ttl     = 3600    # 1 hour

    # Response headers policy for HTML
    response_headers_policy_id = aws_cloudfront_response_headers_policy.html.id
  }

  # Geographic restrictions
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # SSL Certificate
  viewer_certificate {
    acm_certificate_arn            = var.ssl_certificate_arn
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.2_2021"
    cloudfront_default_certificate = var.ssl_certificate_arn == null
  }

  # Logging configuration
  dynamic "logging_config" {
    for_each = var.enable_logging ? [1] : []
    content {
      include_cookies = false
      bucket          = var.logging_bucket
      prefix          = var.logging_prefix
    }
  }

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-spa-distribution"
    Type        = "CloudFront"
    Environment = var.environment
  })
}

# Response Headers Policy for Static Assets
resource "aws_cloudfront_response_headers_policy" "assets" {
  name    = "${var.name_prefix}-assets-policy"
  comment = "Response headers for static assets"

  cors_config {
    access_control_allow_credentials = false

    access_control_allow_headers {
      items = ["*"]
    }

    access_control_allow_methods {
      items = ["GET", "HEAD", "OPTIONS"]
    }

    access_control_allow_origins {
      items = var.cors_allowed_origins
    }

    origin_override = false
  }

  security_headers_config {
    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }
  }

  custom_headers_config {
    items {
      header   = "Cache-Control"
      value    = "public, max-age=31536000, immutable"
      override = false
    }
  }
}

# Response Headers Policy for HTML
resource "aws_cloudfront_response_headers_policy" "html" {
  name    = "${var.name_prefix}-html-policy"
  comment = "Response headers for HTML and SPA routes"

  cors_config {
    access_control_allow_credentials = false

    access_control_allow_headers {
      items = ["*"]
    }

    access_control_allow_methods {
      items = ["GET", "HEAD", "OPTIONS", "POST", "PUT", "DELETE"]
    }

    access_control_allow_origins {
      items = var.cors_allowed_origins
    }

    origin_override = false
  }

  security_headers_config {
    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "SAMEORIGIN"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }
  }

  custom_headers_config {
    items {
      header   = "Cache-Control"
      value    = "public, max-age=300, must-revalidate"
      override = false
    }
  }
}

# S3 Bucket Policy for CloudFront OAI
resource "aws_s3_bucket_policy" "spa_bucket_policy" {
  bucket = var.s3_bucket_name

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "PolicyForCloudFrontPrivateContent"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.spa.iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::${var.s3_bucket_name}/*"
      },
    ]
  })
}
