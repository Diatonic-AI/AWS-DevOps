# CloudFront SPA Module Outputs

output "distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.spa.id
}

output "distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.spa.arn
}

output "distribution_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.spa.domain_name
}

output "distribution_hosted_zone_id" {
  description = "CloudFront distribution hosted zone ID"
  value       = aws_cloudfront_distribution.spa.hosted_zone_id
}

output "origin_access_identity_id" {
  description = "Origin Access Identity ID"
  value       = aws_cloudfront_origin_access_identity.spa.id
}

output "origin_access_identity_iam_arn" {
  description = "Origin Access Identity IAM ARN"
  value       = aws_cloudfront_origin_access_identity.spa.iam_arn
}

output "cloudfront_function_arn" {
  description = "CloudFront Function ARN for SPA routing"
  value       = aws_cloudfront_function.spa_routing.arn
}

output "assets_response_headers_policy_id" {
  description = "Response headers policy ID for assets"
  value       = aws_cloudfront_response_headers_policy.assets.id
}

output "html_response_headers_policy_id" {
  description = "Response headers policy ID for HTML"
  value       = aws_cloudfront_response_headers_policy.html.id
}
