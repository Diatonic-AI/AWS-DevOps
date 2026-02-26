# S3 Bucket for AI Nexus file uploads
resource "aws_s3_bucket" "ai_nexus_uploads" {
  bucket = "${var.project_name}-${var.environment}-ai-nexus-uploads-${random_id.s3_suffix.hex}"

  tags = {
    Name        = "${var.project_name}-${var.environment}-ai-nexus-uploads"
    Environment = var.environment
    Project     = var.project_name
    Application = "ai-nexus-workbench"
  }
}

resource "random_id" "s3_suffix" {
  byte_length = 4
}

# S3 Bucket versioning
resource "aws_s3_bucket_versioning" "ai_nexus_uploads_versioning" {
  bucket = aws_s3_bucket.ai_nexus_uploads.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "ai_nexus_uploads_encryption" {
  bucket = aws_s3_bucket.ai_nexus_uploads.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket public access block
resource "aws_s3_bucket_public_access_block" "ai_nexus_uploads_pab" {
  bucket = aws_s3_bucket.ai_nexus_uploads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket CORS configuration for file uploads
resource "aws_s3_bucket_cors_configuration" "ai_nexus_uploads_cors" {
  bucket = aws_s3_bucket.ai_nexus_uploads.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = [
      "http://localhost:8080",
      "http://localhost:3000",
      "https://${var.domain_name}",
      "https://www.${var.domain_name}"
    ]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# S3 Bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "ai_nexus_uploads_lifecycle" {
  bucket = aws_s3_bucket.ai_nexus_uploads.id

  rule {
    id     = "cleanup_incomplete_uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "transition_to_ia"
    status = "Enabled"

    filter {
      prefix = "uploads/"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }

  rule {
    id     = "cleanup_temp_files"
    status = "Enabled"

    filter {
      prefix = "temp/"
    }

    expiration {
      days = 1
    }
  }
}

# S3 Bucket policy for Cognito users
resource "aws_s3_bucket_policy" "ai_nexus_uploads_policy" {
  bucket = aws_s3_bucket.ai_nexus_uploads.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAuthenticatedUsersAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.authenticated.arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.ai_nexus_uploads.arn}/private/$${aws:userid}/*"
      },
      {
        Sid    = "AllowListBucketForUsers"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.authenticated.arn
        }
        Action = "s3:ListBucket"
        Resource = aws_s3_bucket.ai_nexus_uploads.arn
        Condition = {
          StringLike = {
            "s3:prefix" = "private/$${aws:userid}/"
          }
        }
      },
      {
        Sid    = "AllowPublicUploadsAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.authenticated.arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.ai_nexus_uploads.arn}/public/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.ai_nexus_uploads_pab]
}

# CloudFront distribution for S3 bucket (optional - for performance)
resource "aws_cloudfront_origin_access_control" "ai_nexus_uploads_oac" {
  name                              = "${var.project_name}-${var.environment}-ai-nexus-uploads-oac"
  description                       = "Origin Access Control for AI Nexus uploads bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "ai_nexus_uploads_cdn" {
  count = var.enable_cdn ? 1 : 0

  origin {
    domain_name              = aws_s3_bucket.ai_nexus_uploads.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.ai_nexus_uploads.bucket}"
    origin_access_control_id = aws_cloudfront_origin_access_control.ai_nexus_uploads_oac.id
  }

  enabled = true
  comment = "CDN for AI Nexus uploads"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.ai_nexus_uploads.bucket}"

    forwarded_values {
      query_string = false
      headers      = ["Origin", "Access-Control-Request-Headers", "Access-Control-Request-Method"]
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    response_headers_policy_id = aws_cloudfront_response_headers_policy.ai_nexus_uploads_headers[0].id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ai-nexus-uploads-cdn"
    Environment = var.environment
    Project     = var.project_name
    Application = "ai-nexus-workbench"
  }
}

# CloudFront response headers policy for CORS
resource "aws_cloudfront_response_headers_policy" "ai_nexus_uploads_headers" {
  count = var.enable_cdn ? 1 : 0
  name  = "${var.project_name}-${var.environment}-ai-nexus-uploads-headers"

  cors_config {
    access_control_allow_credentials = false

    access_control_allow_headers {
      items = ["*"]
    }

    access_control_allow_methods {
      items = ["GET", "POST", "PUT", "DELETE", "HEAD", "OPTIONS"]
    }

    access_control_allow_origins {
      items = [
        "http://localhost:8080",
        "http://localhost:3000",
        "https://${var.domain_name}",
        "https://www.${var.domain_name}"
      ]
    }

    access_control_expose_headers {
      items = ["ETag"]
    }

    access_control_max_age_sec = 3600
    origin_override            = true
  }
}

# Outputs
output "ai_nexus_s3_bucket_name" {
  description = "Name of the S3 bucket for file uploads"
  value       = aws_s3_bucket.ai_nexus_uploads.bucket
}

output "ai_nexus_s3_bucket_arn" {
  description = "ARN of the S3 bucket for file uploads"
  value       = aws_s3_bucket.ai_nexus_uploads.arn
}

output "ai_nexus_s3_bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.ai_nexus_uploads.bucket_domain_name
}

output "ai_nexus_cloudfront_distribution_id" {
  description = "CloudFront distribution ID for uploads CDN"
  value       = var.enable_cdn ? aws_cloudfront_distribution.ai_nexus_uploads_cdn[0].id : null
}

output "ai_nexus_cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = var.enable_cdn ? aws_cloudfront_distribution.ai_nexus_uploads_cdn[0].domain_name : null
}
