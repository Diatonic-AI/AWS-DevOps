# AI Nexus Workbench Module Outputs

output "ai_nexus_bucket_id" {
  description = "ID of the AI Nexus S3 bucket"
  value       = aws_s3_bucket.ai_nexus_placeholder.id
}

output "ai_nexus_bucket_arn" {
  description = "ARN of the AI Nexus S3 bucket"
  value       = aws_s3_bucket.ai_nexus_placeholder.arn
}

output "ai_nexus_bucket_domain_name" {
  description = "Domain name of the AI Nexus S3 bucket"
  value       = aws_s3_bucket.ai_nexus_placeholder.bucket_domain_name
}
