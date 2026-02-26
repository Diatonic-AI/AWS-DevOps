terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws" version = "~> 5.0" }
  }
  # backend "s3" {} # Fill with prod state bucket/key
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "ai-nexus-workbench"
      Environment = "prod"
      ManagedBy   = "terraform"
      Owner       = "platform-team"
    }
  }
}
