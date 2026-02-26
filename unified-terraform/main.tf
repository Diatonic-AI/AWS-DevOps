# Unified AWS-DevOps Terraform Configuration
# This is the single root configuration that manages all infrastructure and applications
# Uses Terraform workspaces for environment isolation

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Unified S3 backend with workspace isolation
  backend "s3" {
    bucket         = "aws-devops-terraform-state-unified-xewhyolb"
    key            = "unified/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "aws-devops-terraform-state-lock"
    encrypt        = true

    # Workspace isolation - each workspace gets its own state file
    workspace_key_prefix = "workspaces"
  }
}

# Configure AWS Provider with default tags
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(var.common_tags, {
      Environment  = local.environment
      Workspace    = terraform.workspace
      ManagedBy    = "Terraform-Unified"
      Project      = var.project_name
      Region       = var.aws_region
      LastModified = formatdate("YYYY-MM-DD hh:mm:ss ZZZ", timestamp())
    })
  }

  ignore_tags {
    key_prefixes = ["aws:", "kubernetes.io/", "k8s.io/"]
    keys         = ["CreatedDate", "LastModifiedDate"]
  }
}

# Configure Cloudflare Provider
provider "cloudflare" {
  # Use API Token (recommended)
  api_token = var.cloudflare_api_token != null && var.cloudflare_api_token != "" ? var.cloudflare_api_token : null
}

# Data sources for AWS information
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# Random resources for unique naming
resource "random_string" "unique_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Local values and workspace-specific configurations
locals {
  # Account and region info
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  partition  = data.aws_partition.current.partition

  # Environment mapping from workspace
  environment = local.workspace_environments[terraform.workspace]

  # Workspace to environment mapping
  workspace_environments = {
    default    = "dev"
    dev        = "dev"
    staging    = "staging"
    prod       = "prod"
    ai-nexus   = "dev" # AI Nexus specific workspace
    minio      = "dev" # MinIO specific workspace
    cloudflare = "dev" # Cloudflare specific workspace
  }

  # Environment-specific configurations
  environment_configs = {
    dev = {
      vpc_cidr                   = "10.0.0.0/16"
      nat_gateway_count          = 1 # Cost optimization for dev
      enable_nat_instance        = true
      enable_flow_logs           = false
      enable_backup              = false
      log_retention_days         = 7
      enable_waf                 = false
      enable_detailed_monitoring = false
      min_capacity               = 1
      max_capacity               = 2
      desired_capacity           = 1
    }
    staging = {
      vpc_cidr                   = "10.1.0.0/16"
      nat_gateway_count          = 2
      enable_nat_instance        = false
      enable_flow_logs           = true
      enable_backup              = true
      log_retention_days         = 30
      enable_waf                 = false
      enable_detailed_monitoring = true
      min_capacity               = 1
      max_capacity               = 3
      desired_capacity           = 2
    }
    prod = {
      vpc_cidr                   = "10.2.0.0/16"
      nat_gateway_count          = 3
      enable_nat_instance        = false
      enable_flow_logs           = true
      enable_backup              = true
      log_retention_days         = 90
      enable_waf                 = true
      enable_detailed_monitoring = true
      min_capacity               = 2
      max_capacity               = 10
      desired_capacity           = 3
    }
  }

  current_env_config = local.environment_configs[local.environment]

  # Availability zones (limit to 3 for cost optimization)
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 3)

  # Common resource naming
  name_prefix   = "${var.project_name}-${local.environment}"
  unique_suffix = random_string.unique_suffix.result

  # Application-specific configurations
  applications = {
    core = {
      enabled = contains(["core", "default", "dev", "staging", "prod"], terraform.workspace)
    }
    ai_nexus = {
      enabled = contains(["ai-nexus", "default", "dev", "staging", "prod"], terraform.workspace)
    }
    minio = {
      enabled = contains(["minio", "default", "dev"], terraform.workspace)
    }
    cloudflare = {
      enabled = var.enable_cloudflare
    }
  }

  # Common tags
  common_tags = merge(var.common_tags, {
    Environment = local.environment
    Workspace   = terraform.workspace
    Account     = local.account_id
    Terraform   = "unified"
    UniqueId    = local.unique_suffix
  })
}

# Core Infrastructure Module - Always deployed
module "core_infrastructure" {
  source = "./modules/core-infrastructure"
  count  = local.applications.core.enabled ? 1 : 0

  # Core configuration
  project_name  = var.project_name
  environment   = local.environment
  aws_region    = var.aws_region
  name_prefix   = local.name_prefix
  unique_suffix = local.unique_suffix

  # VPC Configuration
  vpc_cidr            = local.current_env_config.vpc_cidr
  availability_zones  = local.availability_zones
  nat_gateway_count   = local.current_env_config.nat_gateway_count
  enable_nat_instance = local.current_env_config.enable_nat_instance

  # Feature flags from environment config
  enable_flow_logs = local.current_env_config.enable_flow_logs
  enable_backup    = local.current_env_config.enable_backup

  # Common tags
  common_tags = local.common_tags
}

# AI Nexus Application Module - Conditional deployment
module "ai_nexus_workbench" {
  source = "./modules/ai-nexus-workbench"
  count  = local.applications.ai_nexus.enabled ? 1 : 0

  # Core configuration
  project_name  = var.project_name
  environment   = local.environment
  aws_region    = var.aws_region
  name_prefix   = local.name_prefix
  unique_suffix = local.unique_suffix

  # VPC dependencies (use core infrastructure VPC if available)
  vpc_id             = local.applications.core.enabled ? module.core_infrastructure[0].vpc_id : null
  private_subnet_ids = local.applications.core.enabled ? module.core_infrastructure[0].private_subnet_ids : []
  public_subnet_ids  = local.applications.core.enabled ? module.core_infrastructure[0].public_subnet_ids : []

  # AI Nexus specific configuration
  log_retention_days = local.current_env_config.log_retention_days
  enable_waf         = local.current_env_config.enable_waf

  # Scaling configuration
  min_capacity     = local.current_env_config.min_capacity
  max_capacity     = local.current_env_config.max_capacity
  desired_capacity = local.current_env_config.desired_capacity

  # Common tags
  common_tags = local.common_tags

  depends_on = [module.core_infrastructure]
}

# MinIO Infrastructure Module - Conditional deployment
module "minio_infrastructure" {
  source = "./modules/minio"
  count  = local.applications.minio.enabled ? 1 : 0

  # Core configuration
  project_name  = var.project_name
  environment   = local.environment
  aws_region    = var.aws_region
  name_prefix   = local.name_prefix
  unique_suffix = local.unique_suffix

  # VPC dependencies
  vpc_id             = local.applications.core.enabled ? module.core_infrastructure[0].vpc_id : null
  private_subnet_ids = local.applications.core.enabled ? module.core_infrastructure[0].private_subnet_ids : []

  # MinIO specific configuration
  enable_backup = local.current_env_config.enable_backup

  # Common tags
  common_tags = local.common_tags

  depends_on = [module.core_infrastructure]
}

# CloudFront SPA Distribution for Diatonic.ai
module "diatonic_cloudfront" {
  source = "./modules/cloudfront-spa"
  count  = contains(["prod", "dev"], terraform.workspace) ? 1 : 0

  # Core configuration
  name_prefix  = "${local.name_prefix}-diatonic"
  environment  = local.environment
  domain_name  = "diatonic.ai"
  domain_names = ["diatonic.ai", "www.diatonic.ai"]

  # S3 Origin Configuration
  s3_bucket_name        = "diatonic-prod-frontend-bnhhi105"
  s3_bucket_domain_name = "diatonic-prod-frontend-bnhhi105.s3.amazonaws.com"

  # SSL Configuration (requires ACM certificate in us-east-1)
  ssl_certificate_arn = var.diatonic_ssl_certificate_arn
  
  # Performance and Security
  price_class = local.environment == "prod" ? "PriceClass_200" : "PriceClass_100"
  cors_allowed_origins = [
    "https://diatonic.ai",
    "https://www.diatonic.ai",
    "https://app.diatonic.ai"
  ]
  
  # Logging (enable in production)
  enable_logging  = local.environment == "prod"
  logging_bucket  = local.environment == "prod" ? "${local.name_prefix}-cloudfront-logs" : ""
  logging_prefix  = "diatonic-cloudfront/"

  # Common tags
  common_tags = merge(local.common_tags, {
    Application = "Diatonic-AI-Frontend"
    Component   = "CloudFront-SPA"
  })
}

# Cloudflare DNS and CDN Module - Conditional deployment
module "cloudflare" {
  source = "./modules/cloudflare"
  count  = local.applications.cloudflare.enabled ? 1 : 0

  # Cloudflare configuration
  cloudflare_zone_id    = var.cloudflare_zone_id
  cloudflare_account_id = var.cloudflare_account_id
  domain_name           = var.domain_name
  
  # AWS CloudFront integration - Use new SPA distribution if available
  cloudfront_domain     = try(module.diatonic_cloudfront[0].distribution_domain_name, 
                             local.applications.ai_nexus.enabled ? module.ai_nexus_workbench[0].cloudfront_domain : var.default_cloudfront_domain)
  dev_cloudfront_domain = var.dev_cloudfront_domain
  api_domain           = var.api_custom_domain
  
  # Environment-specific configuration
  environment       = local.environment
  development_mode  = local.environment == "dev"
  ssl_mode         = local.environment == "prod" ? "strict" : "full"
  security_level   = local.environment == "prod" ? "high" : "medium"
  
  # Performance tuning based on environment
  enable_rocket_loader  = local.environment != "dev"
  enable_bot_protection = local.environment == "prod"
  enable_rate_limiting  = local.environment == "prod"
  
  # Common tags
  common_tags = local.common_tags

  # Depend on CloudFront distribution
  depends_on = [module.diatonic_cloudfront]
}
