# Global variables and locals shared across all environments
# These are referenced by environment-specific configurations

locals {
  # Project naming convention
  project_name = "pcw"  # Partner Central Wrapper

  # Common tags applied to all resources
  common_tags = {
    Project     = "partnercentral-wrapper"
    ManagedBy   = "terraform"
    Repository  = "aws-partner-central-wrapper"
  }

  # AWS regions configuration
  primary_region   = "us-east-1"
  secondary_region = "us-west-2"

  # Network CIDR blocks by environment
  cidr_blocks = {
    dev   = "10.60.0.0/16"
    stage = "10.70.0.0/16"
    prod  = "10.80.0.0/16"
  }

  # Availability zones (will be resolved per region)
  az_count = 3

  # Database configurations
  db_config = {
    dev = {
      instance_class    = "db.t3.medium"
      allocated_storage = 20
      multi_az          = false
    }
    stage = {
      instance_class    = "db.r6g.large"
      allocated_storage = 100
      multi_az          = true
    }
    prod = {
      instance_class    = "db.r6g.xlarge"
      allocated_storage = 500
      multi_az          = true
    }
  }

  # Redshift Serverless configurations
  redshift_config = {
    dev = {
      base_capacity = 8
      max_capacity  = 32
    }
    stage = {
      base_capacity = 32
      max_capacity  = 128
    }
    prod = {
      base_capacity = 64
      max_capacity  = 512
    }
  }

  # Lambda configurations
  lambda_config = {
    memory_size_default = 256
    timeout_default     = 30
    runtime             = "python3.11"
  }
}
