provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.env
      Project     = "partnercentral-wrapper"
      ManagedBy   = "terraform"
    }
  }
}

locals {
  name = "pcw-${var.env}"
  tags = {
    project = "partnercentral-wrapper"
    env     = var.env
  }
}

# Core VPC and Networking
module "core_network" {
  source = "../../modules/core-network"
  name   = local.name
  cidr   = var.vpc_cidr
  tags   = local.tags
}

# KMS Keys for encryption
module "kms" {
  source = "../../modules/security-kms"
  name   = local.name
  tags   = local.tags
}

# Secrets Manager baseline
module "secrets" {
  source      = "../../modules/secrets"
  name        = local.name
  kms_key_arn = module.kms.secrets_key_arn
  tags        = local.tags
}

# EventBridge and eventing infrastructure
module "eventing" {
  source = "../../modules/eventing"
  name   = local.name
  tags   = local.tags
}

# Step Functions orchestration
module "orchestration" {
  source        = "../../modules/orchestration"
  name          = local.name
  event_bus_arn = module.eventing.bus_arn
  dlq_arn       = module.eventing.dlq_arn
  tags          = local.tags
}

# Aurora PostgreSQL (Control Plane DB)
module "operational_db" {
  source      = "../../modules/operational-db"
  name        = local.name
  subnet_ids  = module.core_network.private_subnet_ids
  vpc_id      = module.core_network.vpc_id
  kms_key_arn = module.kms.db_key_arn
  tags        = local.tags
}

# S3 Data Lake
module "data_lake" {
  source      = "../../modules/data-lake"
  name        = local.name
  kms_key_arn = module.kms.lake_key_arn
  tags        = local.tags
}

# Redshift Serverless (Analytics)
module "warehouse" {
  source      = "../../modules/analytics-warehouse"
  name        = local.name
  subnet_ids  = module.core_network.private_subnet_ids
  vpc_id      = module.core_network.vpc_id
  kms_key_arn = module.kms.warehouse_key_arn
  tags        = local.tags
}

# Partner Central IAM access
module "partnercentral_access" {
  source = "../../modules/partner-central-access"
  name   = local.name
  tags   = local.tags
}

# Marketplace IAM access
module "marketplace_access" {
  source = "../../modules/marketplace-access"
  name   = local.name
  tags   = local.tags
}

# Observability (CloudWatch, X-Ray)
module "observability" {
  source = "../../modules/observability"
  name   = local.name
  tags   = local.tags
}
