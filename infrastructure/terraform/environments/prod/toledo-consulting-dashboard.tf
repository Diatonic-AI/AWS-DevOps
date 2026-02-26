# Toledo Consulting Partner Dashboard Deployment
# Production environment configuration

module "toledo_consulting_dashboard" {
  source = "../../modules/partner-dashboard"

  partner_name = "toledo-consulting"
  environment  = "prod"
  aws_region   = "us-east-2"

  common_tags = {
    Partner       = "toledo-consulting"
    CompanyType   = "contractor"
    Services      = "ai-consulting"
    Certification = "veteran-owned"
    Environment   = "prod"
    Project       = "partner-dashboard"
    ManagedBy     = "terraform"
    CreatedBy     = "diatonic-ai"
  }
}

# Outputs for easy access
output "toledo_dashboard_url" {
  description = "URL to access Toledo Consulting dashboard"
  value       = module.toledo_consulting_dashboard.dashboard_url
}

output "toledo_api_url" {
  description = "API Gateway URL for Toledo Consulting dashboard"
  value       = module.toledo_consulting_dashboard.api_gateway_url
}

output "toledo_cloudwatch_dashboard" {
  description = "CloudWatch dashboard URL for Toledo Consulting metrics"
  value       = module.toledo_consulting_dashboard.cloudwatch_dashboard_url
}

output "toledo_s3_bucket_name" {
  description = "S3 bucket name for Toledo Consulting dashboard assets"
  value       = module.toledo_consulting_dashboard.s3_bucket_name
}
