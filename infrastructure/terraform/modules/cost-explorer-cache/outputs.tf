# Outputs for Cost Explorer Cache module

output "partner_dashboard_cache_table_name" {
  description = "Name of the partner dashboard cache table"
  value       = aws_dynamodb_table.partner_dashboard_cache.name
}

output "partner_dashboard_cache_table_arn" {
  description = "ARN of the partner dashboard cache table"
  value       = aws_dynamodb_table.partner_dashboard_cache.arn
}

output "client_billing_cache_table_name" {
  description = "Name of the client billing cache table"
  value       = aws_dynamodb_table.client_billing_cache.name
}

output "client_billing_cache_table_arn" {
  description = "ARN of the client billing cache table"
  value       = aws_dynamodb_table.client_billing_cache.arn
}

output "lambda_cache_access_role_arn" {
  description = "ARN of the IAM role for Lambda cache access"
  value       = aws_iam_role.lambda_cache_access.arn
}

output "lambda_cache_access_role_name" {
  description = "Name of the IAM role for Lambda cache access"
  value       = aws_iam_role.lambda_cache_access.name
}

output "cost_optimization_dashboard_url" {
  description = "URL to the Cost Explorer optimization dashboard"
  value       = var.create_dashboard ? "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.cost_optimization[0].dashboard_name}" : null
}

output "cache_configuration" {
  description = "Cache configuration details for Lambda environment variables"
  value = {
    partner_dashboard_cache_table = aws_dynamodb_table.partner_dashboard_cache.name
    client_billing_cache_table    = aws_dynamodb_table.client_billing_cache.name
    cache_ttl_hours               = var.cache_ttl_hours
    region                        = data.aws_region.current.name
  }
}

output "cost_savings_estimate" {
  description = "Estimated cost savings from implementing caching"
  value = {
    without_caching = {
      description  = "372 API calls per day at $0.01 each"
      daily_cost   = "$3.72"
      monthly_cost = "$112.32"
      yearly_cost  = "$1,357.80"
    }
    with_caching = {
      description  = "~15 API calls per day (cache misses) + DynamoDB costs"
      daily_cost   = "$0.15 + ~$0.05 DynamoDB"
      monthly_cost = "$6.00 + DynamoDB costs"
      yearly_cost  = "$72.00 + DynamoDB costs"
    }
    estimated_monthly_savings = "$100+"
    estimated_yearly_savings  = "$1,250+"
  }
}