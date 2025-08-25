# Terraform Provider Configuration

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

  # Backend configuration will be provided via backend config files or CLI
  # This allows for different backends per environment
  # backend "s3" {
  #   # Configuration will be provided via -backend-config or backend.hcl files
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
    })
  }
}

# Data sources for AWS account and region information
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

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

  # Resource naming
  name_prefix   = var.name_prefix != "" ? "${var.name_prefix}-" : ""
  name_suffix   = var.name_suffix != "" ? "-${var.name_suffix}" : ""
  unique_suffix = random_string.suffix.result

  # Common resource names
  resource_prefix = "${local.name_prefix}${var.project_name}-${var.environment}"

  # Common tags merged with environment-specific tags
  common_tags = merge(var.common_tags, {
    Environment = var.environment
    Region      = var.aws_region
    Account     = local.account_id
  })
}
