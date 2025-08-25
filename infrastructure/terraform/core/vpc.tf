# Core VPC Configuration
# This file creates the primary VPC infrastructure using our custom VPC module

# Local values for VPC configuration
locals {
  vpc_name = "${var.project_name}-${var.environment}-vpc"

  # VPC CIDR blocks
  vpc_cidr = var.environment == "prod" ? "10.0.0.0/16" : "10.1.0.0/16"

  # Calculate subnet CIDRs based on environment
  public_subnet_cidrs = var.environment == "prod" ? [
    "10.0.1.0/24", # us-east-2a public
    "10.0.2.0/24", # us-east-2b public
    "10.0.3.0/24"  # us-east-2c public
    ] : [
    "10.1.1.0/24", # us-east-2a public
    "10.1.2.0/24", # us-east-2b public
    "10.1.3.0/24"  # us-east-2c public
  ]

  private_subnet_cidrs = var.environment == "prod" ? [
    "10.0.11.0/24", # us-east-2a private
    "10.0.12.0/24", # us-east-2b private
    "10.0.13.0/24"  # us-east-2c private
    ] : [
    "10.1.11.0/24", # us-east-2a private
    "10.1.12.0/24", # us-east-2b private
    "10.1.13.0/24"  # us-east-2c private
  ]

  data_subnet_cidrs = var.environment == "prod" ? [
    "10.0.21.0/24", # us-east-2a data
    "10.0.22.0/24", # us-east-2b data
    "10.0.23.0/24"  # us-east-2c data
    ] : [
    "10.1.21.0/24", # us-east-2a data
    "10.1.22.0/24", # us-east-2b data
    "10.1.23.0/24"  # us-east-2c data
  ]

  # Common tags for all VPC resources
  vpc_tags = merge(var.common_tags, {
    Name        = local.vpc_name
    Component   = "networking"
    Tier        = "infrastructure"
    Environment = var.environment
  })
}

# Create the main VPC using our custom module
module "vpc" {
  source = "../modules/vpc"

  # Basic configuration using module variables
  name_prefix = "${var.project_name}-${var.environment}"
  environment = var.environment == "dev" ? "development" : var.environment == "prod" ? "production" : "staging"

  # VPC configuration
  vpc_cidr = local.vpc_cidr
  az_count = 3 # Use 3 AZs for better availability

  # NAT Gateway configuration - cost optimization based on tags
  single_nat_gateway = lookup(var.common_tags, "CostMode", "standard") == "optimized" ? true : (var.environment == "prod" ? false : true)

  # DNS configuration
  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC Endpoints (enabled for cost optimization)
  enable_vpc_endpoints = true

  # Flow Logs (configurable based on environment)
  enable_flow_logs         = var.feature_flags.enable_flow_logs
  flow_logs_retention_days = var.environment == "prod" ? 90 : 30

  # Tags
  tags = local.vpc_tags
}

# Output VPC information for use by other resources
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "data_subnet_ids" {
  description = "IDs of the data subnets"
  value       = module.vpc.data_subnet_ids
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.vpc.internet_gateway_id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = module.vpc.nat_gateway_ids
}

output "database_subnet_group_name" {
  description = "Name of the database subnet group"
  value       = module.vpc.database_subnet_group_name
}

output "elasticache_subnet_group_name" {
  description = "Name of the ElastiCache subnet group"
  value       = module.vpc.elasticache_subnet_group_name
}

# Web Application Outputs
output "web_application_url" {
  description = "URL to access the web application"
  value       = module.web_application.application_url
}

output "web_application_load_balancer_dns" {
  description = "DNS name of the web application load balancer"
  value       = module.web_application.load_balancer_dns_name
}

output "web_application_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.web_application.cluster_name
}

output "web_cdn_distribution_domain_name" {
  description = "CloudFront distribution domain name"
  value       = local.current_web_config.enable_cloudfront ? module.web_cdn[0].distribution_domain_name : null
}

output "web_application_configuration_summary" {
  description = "Web application configuration summary"
  value = {
    environment            = var.environment
    container_image        = local.current_web_config.container_image
    container_cpu          = local.current_web_config.container_cpu
    container_memory       = local.current_web_config.container_memory
    auto_scaling_enabled   = true
    https_enabled          = local.current_web_config.enable_https
    cdn_enabled            = local.current_web_config.enable_cloudfront
    database_enabled       = local.current_web_config.enable_database
    estimated_monthly_cost = module.web_application.estimated_monthly_cost
    access_methods = {
      direct_alb = module.web_application.application_url
      static_s3  = module.s3.static_assets_website_endpoint != null ? "https://${module.s3.static_assets_website_endpoint}" : "S3 static hosting not enabled"
      cdn        = local.current_web_config.enable_cloudfront ? "https://${module.web_cdn[0].distribution_domain_name}" : "Not enabled"
    }
  }
}
