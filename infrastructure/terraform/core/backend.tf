# Terraform Backend Configuration
# This file defines the remote state storage for the AWS DevOps project
# State is stored in S3 with DynamoDB for locking

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Backend configuration for remote state
  # Note: Using local backend for initial setup
  # Uncomment and configure S3 backend after creating the S3 bucket
  # backend "s3" {
  #   bucket         = "aws-devops-terraform-state-313476888312-us-east-2"
  #   key            = "core/terraform.tfstate"
  #   region         = "us-east-2"
  #   dynamodb_table = "aws-devops-terraform-state-lock"
  #   encrypt        = true
  # }
}

# AWS Provider Configuration
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  # Default tags applied to all resources
  default_tags {
    tags = merge(var.common_tags, {
      Environment = var.environment
      Region      = var.aws_region
      ManagedBy   = "Terraform"
      Project     = var.project_name
    })
  }
}

# Data sources for AWS account and region information
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# Random string for unique resource naming
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Local values for common use
locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  partition  = data.aws_partition.current.partition

  # Availability zones (use first 3)
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 3)

  # Resource naming
  name_prefix   = var.name_prefix != "" ? "${var.name_prefix}-" : ""
  name_suffix   = var.name_suffix != "" ? "-${var.name_suffix}" : ""
  unique_suffix = random_string.suffix.result

  # Common resource names
  resource_prefix = "${local.name_prefix}${var.project_name}-${var.environment}"

  # Common tags
  common_tags = merge(var.common_tags, {
    Environment = var.environment
    Region      = var.aws_region
    Account     = local.account_id
    Terraform   = "true"
  })
}
