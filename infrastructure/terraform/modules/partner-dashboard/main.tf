# Toledo Consulting Partner Dashboard Infrastructure
# Terraform module for deploying partner-specific dashboard resources

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Local variables for consistent tagging
locals {
  partner_name = var.partner_name
  common_tags = merge(var.common_tags, {
    Partner       = var.partner_name
    CompanyType   = "contractor"
    Services      = "ai-consulting"
    Certification = "veteran-owned"
    Environment   = var.environment
    Project       = "partner-dashboard"
  })
}

# S3 bucket for dashboard assets
resource "aws_s3_bucket" "dashboard_assets" {
  bucket = "${var.partner_name}-dashboard-assets-${var.environment}"

  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "dashboard_assets" {
  bucket = aws_s3_bucket.dashboard_assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dashboard_assets" {
  bucket = aws_s3_bucket.dashboard_assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "dashboard_assets" {
  bucket = aws_s3_bucket.dashboard_assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for dashboard data
resource "aws_dynamodb_table" "dashboard_data" {
  name           = "${var.partner_name}-dashboard-data"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "pk"
  range_key      = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  attribute {
    name = "gsi1pk"
    type = "S"
  }

  attribute {
    name = "gsi1sk"
    type = "S"
  }

  global_secondary_index {
    name               = "GSI1"
    hash_key          = "gsi1pk"
    range_key         = "gsi1sk"
    projection_type   = "ALL"
  }

  tags = local.common_tags
}

# IAM role for Lambda functions
resource "aws_iam_role" "dashboard_lambda_role" {
  name = "${var.partner_name}-dashboard-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM policy for Lambda functions
resource "aws_iam_role_policy" "dashboard_lambda_policy" {
  name = "${var.partner_name}-dashboard-lambda-policy"
  role = aws_iam_role.dashboard_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.dashboard_data.arn,
          "${aws_dynamodb_table.dashboard_data.arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricData",
          "ec2:DescribeInstances",
          "rds:DescribeDBInstances",
          "s3:ListBucket",
          "s3:GetObject",
          "ce:GetCostAndUsage",
          "ce:GetDimensionValues",
          "ce:GetReservationCoverage",
          "ce:GetReservationPurchaseRecommendation",
          "ce:GetReservationUtilization",
          "ce:GetUsageReport",
          "ce:ListCostCategoryDefinitions"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Partner" = var.partner_name
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.dashboard_assets.arn}/*"
      }
    ]
  })
}

# Lambda function for dashboard API
resource "aws_lambda_function" "dashboard_api" {
  filename         = "dashboard-api.zip"
  source_code_hash = filebase64sha256("dashboard-api.zip")
  function_name    = "${var.partner_name}-dashboard-api"
  role            = aws_iam_role.dashboard_lambda_role.arn
  handler         = "index.handler"
  runtime         = "nodejs16.x"
  timeout         = 30

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.dashboard_data.name
      PARTNER_NAME   = var.partner_name
      S3_BUCKET      = aws_s3_bucket.dashboard_assets.bucket
    }
  }

  tags = local.common_tags
}

# API Gateway for dashboard endpoints
resource "aws_apigatewayv2_api" "dashboard_api" {
  name          = "${var.partner_name}-dashboard-api"
  protocol_type = "HTTP"
  description   = "API Gateway for ${var.partner_name} partner dashboard"

  cors_configuration {
    allow_credentials = false
    allow_headers     = ["content-type", "x-amz-date", "authorization", "x-api-key"]
    allow_methods     = ["*"]
    allow_origins     = ["*"]
    expose_headers    = []
    max_age          = 0
  }

  tags = local.common_tags
}

resource "aws_apigatewayv2_stage" "dashboard_api" {
  api_id      = aws_apigatewayv2_api.dashboard_api.id
  name        = var.environment
  auto_deploy = true

  tags = local.common_tags
}

resource "aws_apigatewayv2_integration" "dashboard_api" {
  api_id           = aws_apigatewayv2_api.dashboard_api.id
  integration_type = "AWS_PROXY"

  connection_type    = "INTERNET"
  description        = "Lambda integration for dashboard API"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.dashboard_api.invoke_arn
}

resource "aws_apigatewayv2_route" "dashboard_api" {
  api_id    = aws_apigatewayv2_api.dashboard_api.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.dashboard_api.id}"
}

resource "aws_lambda_permission" "dashboard_api" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dashboard_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.dashboard_api.execution_arn}/*/*"
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "dashboard_api" {
  name              = "/aws/lambda/${aws_lambda_function.dashboard_api.function_name}"
  retention_in_days = 14

  tags = local.common_tags
}

# CloudWatch Dashboard for partner metrics
resource "aws_cloudwatch_dashboard" "partner_dashboard" {
  dashboard_name = "${var.partner_name}-partner-metrics"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.dashboard_api.function_name],
            [".", "Errors", ".", "."],
            [".", "Invocations", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Dashboard API Lambda Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", aws_dynamodb_table.dashboard_data.name],
            [".", "ConsumedWriteCapacityUnits", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Dashboard DynamoDB Metrics"
          period  = 300
        }
      }
    ]
  })
}

# CloudFront distribution for dashboard
resource "aws_cloudfront_distribution" "dashboard" {
  origin {
    domain_name = aws_s3_bucket.dashboard_assets.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.dashboard_assets.bucket}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.dashboard.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.partner_name} Partner Dashboard"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.dashboard_assets.bucket}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = local.common_tags
}

resource "aws_cloudfront_origin_access_identity" "dashboard" {
  comment = "${var.partner_name} dashboard OAI"
}

# S3 bucket policy for CloudFront access
resource "aws_s3_bucket_policy" "dashboard_assets" {
  bucket = aws_s3_bucket.dashboard_assets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontAccess"
        Effect    = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.dashboard.iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.dashboard_assets.arn}/*"
      }
    ]
  })
}