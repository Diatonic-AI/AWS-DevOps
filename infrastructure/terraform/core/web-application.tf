# Web Application Infrastructure
# This file creates the complete web application hosting infrastructure

# Local values for web application configuration
locals {
  web_app_name_prefix = "${var.project_name}-${var.environment}"

  # Environment-specific web application configuration
  web_app_config = {
    development = {
      # ECS Configuration
      container_cpu    = 256
      container_memory = 512
      min_capacity     = 1
      max_capacity     = 2
      desired_capacity = 1

      # Domain Configuration (Cloudflare integration)
      enable_custom_domain = var.web_app_domain_name != null
      domain_name          = var.web_app_domain_name # Set to dev.yourdomain.com
      enable_https         = var.enable_https        # Use explicit HTTPS flag

      # Database Configuration
      enable_database         = false
      database_instance_class = "db.t3.micro"

      # CDN Configuration (disabled - Cloudflare handles CDN)
      enable_cloudfront      = false # Cloudflare CDN instead
      cloudfront_price_class = "PriceClass_100"

      # Monitoring
      enable_detailed_monitoring = false

      # Sample Application
      container_image = "nginx:alpine" # Lightweight web server for demo
      environment_variables = [
        {
          name  = "NGINX_PORT"
          value = "80"
        },
        {
          name  = "DOMAIN_NAME"
          value = var.web_app_domain_name != null ? var.web_app_domain_name : "localhost"
        }
      ]
    }

    staging = {
      # ECS Configuration
      container_cpu    = 512
      container_memory = 1024
      min_capacity     = 1
      max_capacity     = 5
      desired_capacity = 2

      # Domain Configuration
      enable_custom_domain = true
      domain_name          = "staging.${var.project_name}.com"
      enable_https         = var.enable_https

      # Database Configuration
      enable_database         = true
      database_instance_class = "db.t3.micro"

      # CDN Configuration
      enable_cloudfront      = true
      cloudfront_price_class = "PriceClass_200"

      # Monitoring
      enable_detailed_monitoring = true

      # Application Configuration
      container_image = var.web_app_container_image != null ? var.web_app_container_image : "nginx:alpine"
    }

    production = {
      # ECS Configuration
      container_cpu    = 1024
      container_memory = 2048
      min_capacity     = 2
      max_capacity     = 20
      desired_capacity = 3

      # Domain Configuration
      enable_custom_domain = true
      domain_name          = "${var.project_name}.com"
      enable_https         = var.enable_https

      # Database Configuration
      enable_database         = true
      database_instance_class = "db.t3.small"

      # CDN Configuration
      enable_cloudfront      = true
      cloudfront_price_class = "PriceClass_All"

      # Monitoring
      enable_detailed_monitoring = true

      # Application Configuration
      container_image = var.web_app_container_image != null ? var.web_app_container_image : "nginx:alpine"
    }
  }

  # Current environment configuration
  current_web_config = local.web_app_config[var.environment == "dev" ? "development" : var.environment == "prod" ? "production" : "staging"]
}

# ECS Fargate Web Application
module "web_application" {
  source = "../modules/ecs"

  # Basic configuration
  name_prefix        = local.web_app_name_prefix
  environment        = var.environment == "dev" ? "development" : var.environment == "prod" ? "production" : "staging"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  # Container configuration
  container_image  = local.current_web_config.container_image
  container_cpu    = local.current_web_config.container_cpu
  container_memory = local.current_web_config.container_memory
  container_port   = 80

  # Scaling configuration
  min_capacity     = local.current_web_config.min_capacity
  max_capacity     = local.current_web_config.max_capacity
  desired_capacity = local.current_web_config.desired_capacity

  # Cost optimization
  enable_auto_scaling = true

  # Environment variables
  environment_variables = concat(
    lookup(local.current_web_config, "environment_variables", []),
    [
      {
        name  = "ENVIRONMENT"
        value = var.environment
      },
      {
        name  = "PROJECT_NAME"
        value = var.project_name
      }
    ]
  )

  # Domain and SSL configuration
  domain_name  = local.current_web_config.domain_name
  enable_https = local.current_web_config.enable_https
  # certificate_arn will be set after ACM certificate creation

  # Security
  allowed_cidr_blocks = var.allowed_cidr_blocks

  # Logging
  enable_logging     = true
  log_retention_days = var.environment == "prod" ? 30 : 7

  # Health check
  health_check_path = "/"

  # Tags
  tags = merge(local.common_tags, {
    Component = "web-application"
    Tier      = "application"
  })
}

# Route53 DNS Management (Create first for certificate validation)
module "dns" {
  count  = var.enable_route53 ? 1 : 0
  source = "../modules/route53"

  name_prefix = local.web_app_name_prefix
  environment = var.environment == "dev" ? "development" : var.environment == "prod" ? "production" : "staging"

  # Domain configuration
  domain_name = var.web_app_domain_name
  create_zone = var.create_hosted_zone
  zone_id     = var.existing_zone_id

  # CloudFront integration (will be null initially, updated after CloudFront is created)
  cloudfront_distribution_domain_name    = null
  cloudfront_distribution_hosted_zone_id = null

  # Load balancer integration (pass null initially to avoid count dependency issues)
  load_balancer_domain_name    = null # Will be updated in a separate DNS update step
  load_balancer_hosted_zone_id = null

  # Certificate validation records (will be empty initially, updated after certificate creation)
  certificate_validation_records = []

  # Subdomain configuration (basic setup initially)
  subdomains = []

  # Health checks
  health_checks = var.enable_health_checks ? [
    {
      name                    = "primary-domain"
      type                    = "HTTPS"
      fqdn                    = var.web_app_domain_name
      port                    = 443
      resource_path           = "/"
      failure_threshold       = 3
      request_interval        = 30
      cloudwatch_alarm_region = var.aws_region
      # insufficient_data_health_status not needed for basic health checks
      tags = {
        Name = "${local.web_app_name_prefix}-primary-health-check"
      }
    }
  ] : []

  tags = merge(local.common_tags, {
    Component = "dns"
    Tier      = "networking"
  })
}

# SSL Certificate (ACM) - depends on DNS zone
module "ssl_certificate" {
  count  = var.enable_https && var.web_app_domain_name != null ? 1 : 0
  source = "../modules/acm"

  depends_on = [module.dns]

  name_prefix = local.web_app_name_prefix
  environment = var.environment == "dev" ? "development" : var.environment == "prod" ? "production" : "staging"

  # Domain configuration
  domain_name = var.web_app_domain_name
  subject_alternative_names = [
    "www.${var.web_app_domain_name}",
    "app.${var.web_app_domain_name}",
    "admin.${var.web_app_domain_name}",
    "api.${var.web_app_domain_name}"
  ]
  include_wildcard = true

  # DNS validation via Route53
  validation_method = "DNS"
  route53_zone_id   = var.enable_route53 && var.create_hosted_zone ? module.dns[0].hosted_zone_id : var.existing_zone_id

  # Monitoring
  enable_expiry_monitoring  = true
  enable_renewal_monitoring = true

  tags = merge(local.common_tags, {
    Component = "ssl-certificate"
    Tier      = "security"
  })
}

# ALB Route53 Record (separate from main DNS module to avoid count dependency)
resource "aws_route53_record" "alb_main" {
  count = var.enable_route53 && var.web_app_domain_name != null ? 1 : 0

  zone_id = var.enable_route53 && var.create_hosted_zone ? module.dns[0].hosted_zone_id : var.existing_zone_id
  name    = var.web_app_domain_name
  type    = "A"

  alias {
    name                   = module.web_application.load_balancer_dns_name
    zone_id                = module.web_application.load_balancer_zone_id
    evaluate_target_health = true
  }

  depends_on = [module.web_application, module.dns]
}

# CloudFront CDN (optional, based on environment)
module "web_cdn" {
  count  = var.enable_cloudfront ? 1 : 0
  source = "../modules/cloudfront"

  name_prefix = local.web_app_name_prefix
  environment = var.environment == "dev" ? "development" : var.environment == "prod" ? "production" : "staging"

  # Origins
  load_balancer_domain_name = module.web_application.load_balancer_dns_name
  s3_bucket_domain_name     = module.s3.static_assets_website_endpoint

  # Domain configuration
  domain_name = var.web_app_domain_name
  alternative_names = [
    "www.${var.web_app_domain_name}",
    "app.${var.web_app_domain_name}",
    "admin.${var.web_app_domain_name}"
  ]

  # SSL configuration
  ssl_certificate_arn      = var.enable_https && length(module.ssl_certificate) > 0 ? module.ssl_certificate[0].certificate_validation_arn : null
  ssl_support_method       = "sni-only"
  minimum_protocol_version = "TLSv1.2_2021"

  # Cost optimization
  price_class = var.environment == "prod" ? "PriceClass_200" : "PriceClass_100"

  # Caching configuration optimized for web apps
  cache_behaviors = [
    {
      path_pattern           = "/api/*"
      target_origin_id       = "ALB-${local.web_app_name_prefix}"
      allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods         = ["GET", "HEAD"]
      compress               = true
      viewer_protocol_policy = "redirect-to-https"
      min_ttl                = 0
      default_ttl            = 0
      max_ttl                = 0
      forward_query_string   = true
      forward_headers        = ["Host", "Authorization", "CloudFront-Forwarded-Proto"]
      forward_cookies        = "all"
    },
    {
      path_pattern           = "/static/*"
      target_origin_id       = "S3-${local.web_app_name_prefix}"
      allowed_methods        = ["GET", "HEAD"]
      cached_methods         = ["GET", "HEAD"]
      compress               = true
      viewer_protocol_policy = "redirect-to-https"
      min_ttl                = 0
      default_ttl            = 86400
      max_ttl                = 31536000
      forward_query_string   = false
      forward_headers        = []
      forward_cookies        = "none"
    }
  ]

  # Custom error pages
  custom_error_responses = [
    {
      error_code            = 404
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 300
    },
    {
      error_code            = 403
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 300
    }
  ]

  # Logging (only in production to save costs)
  enable_logging = var.environment == "prod"
  logging_bucket = var.environment == "prod" ? module.s3.logs_bucket_name : null

  # Tags
  tags = {
    Project     = "AWS-DevOps"
    Environment = "dev"
    Component   = "homepage"
    Type        = "static-content"
    ManagedBy   = "Terraform"
  }
}

# Simple homepage for immediate deployment
resource "aws_s3_object" "homepage" {
  bucket       = module.s3.static_assets_bucket_name
  key          = "index.html"
  content_type = "text/html"

  depends_on = [module.s3]

  content = <<-EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${var.project_name} - Welcome</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: #333;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        
        .container {
            background: rgba(255, 255, 255, 0.95);
            padding: 3rem;
            border-radius: 20px;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
            text-align: center;
            max-width: 600px;
            backdrop-filter: blur(10px);
        }
        
        .logo {
            font-size: 3rem;
            font-weight: bold;
            margin-bottom: 1rem;
            background: linear-gradient(135deg, #667eea, #764ba2);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        
        h1 {
            color: #2c3e50;
            margin-bottom: 1rem;
            font-size: 2.5rem;
        }
        
        p {
            margin-bottom: 1.5rem;
            font-size: 1.2rem;
            color: #666;
        }
        
        .status-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
            margin: 2rem 0;
        }
        
        .status-card {
            background: #f8f9fa;
            padding: 1.5rem;
            border-radius: 10px;
            border-left: 4px solid #28a745;
        }
        
        .status-card h3 {
            color: #2c3e50;
            margin-bottom: 0.5rem;
        }
        
        .status-card p {
            color: #28a745;
            font-weight: bold;
            margin: 0;
            font-size: 1rem;
        }
        
        .info-section {
            margin-top: 2rem;
            padding-top: 2rem;
            border-top: 1px solid #eee;
        }
        
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 1rem;
            text-align: left;
            margin-top: 1rem;
        }
        
        .info-item {
            background: #f8f9fa;
            padding: 1rem;
            border-radius: 8px;
        }
        
        .info-item strong {
            color: #2c3e50;
            display: block;
            margin-bottom: 0.25rem;
        }
        
        .info-item span {
            color: #666;
            font-size: 0.9rem;
        }
        
        .footer {
            margin-top: 2rem;
            color: #999;
            font-size: 0.9rem;
        }
        
        @media (max-width: 768px) {
            .container {
                margin: 1rem;
                padding: 2rem;
            }
            
            h1 {
                font-size: 2rem;
            }
            
            .logo {
                font-size: 2rem;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🚀</div>
        <h1>Welcome to ${var.project_name}</h1>
        <p>Your AWS-powered web application is now live!</p>
        
        <div class="status-grid">
            <div class="status-card">
                <h3>Infrastructure</h3>
                <p>✅ Ready</p>
            </div>
            <div class="status-card">
                <h3>Application</h3>
                <p>✅ Running</p>
            </div>
            <div class="status-card">
                <h3>Security</h3>
                <p>✅ Enabled</p>
            </div>
        </div>
        
        <div class="info-section">
            <h3>Infrastructure Overview</h3>
            <div class="info-grid">
                <div class="info-item">
                    <strong>Environment</strong>
                    <span>${var.environment}</span>
                </div>
                <div class="info-item">
                    <strong>Region</strong>
                    <span>${var.aws_region}</span>
                </div>
                <div class="info-item">
                    <strong>Compute</strong>
                    <span>ECS Fargate</span>
                </div>
                <div class="info-item">
                    <strong>Storage</strong>
                    <span>S3 + CloudFront</span>
                </div>
            </div>
        </div>
        
        <div class="footer">
            <p>🏗️ Built with Terraform on AWS • Environment: ${var.environment} • Last Updated: $(date)</p>
            <p>Ready to start building your application!</p>
        </div>
    </div>
</body>
</html>
EOF

  tags = {
    Project     = "AWS-DevOps"
    Environment = var.environment
    Component   = "homepage"
    Type        = "static-content"
    ManagedBy   = "Terraform"
  }
}

# Error page
resource "aws_s3_object" "error_page" {
  bucket       = module.s3.static_assets_bucket_name
  key          = "error.html"
  content_type = "text/html"

  depends_on = [module.s3]

  content = <<-EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Page Not Found - ${var.project_name}</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #ff6b6b 0%, #ee5a24 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            text-align: center;
        }
        
        .container {
            background: rgba(255, 255, 255, 0.1);
            padding: 3rem;
            border-radius: 20px;
            backdrop-filter: blur(10px);
        }
        
        h1 { font-size: 4rem; margin-bottom: 1rem; }
        p { font-size: 1.5rem; margin-bottom: 2rem; }
        a { color: white; text-decoration: none; background: rgba(255,255,255,0.2); padding: 1rem 2rem; border-radius: 10px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>404</h1>
        <p>Oops! Page not found.</p>
        <a href="/">← Go Home</a>
    </div>
</body>
</html>
EOF

  tags = {
    Project     = "AWS-DevOps"
    Environment = var.environment
    Component   = "error-page"
    Type        = "static-content"
    ManagedBy   = "Terraform"
  }
}
