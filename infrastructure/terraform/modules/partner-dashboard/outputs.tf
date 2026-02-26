output "s3_bucket_name" {
  description = "Name of the S3 bucket for dashboard assets"
  value       = aws_s3_bucket.dashboard_assets.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for dashboard assets"
  value       = aws_s3_bucket.dashboard_assets.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for dashboard data"
  value       = aws_dynamodb_table.dashboard_data.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for dashboard data"
  value       = aws_dynamodb_table.dashboard_data.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function for dashboard API"
  value       = aws_lambda_function.dashboard_api.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function for dashboard API"
  value       = aws_lambda_function.dashboard_api.arn
}

output "api_gateway_url" {
  description = "URL of the API Gateway for dashboard endpoints"
  value       = aws_apigatewayv2_stage.dashboard_api.invoke_url
}

output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = aws_apigatewayv2_api.dashboard_api.id
}

output "cloudwatch_dashboard_url" {
  description = "URL to the CloudWatch dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.partner_dashboard.dashboard_name}"
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.dashboard.id
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.dashboard.domain_name
}

output "dashboard_url" {
  description = "URL to access the partner dashboard"
  value       = "https://${aws_cloudfront_distribution.dashboard.domain_name}"
}