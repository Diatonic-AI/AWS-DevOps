# MinIO Infrastructure Module Outputs

output "minio_bucket_id" {
  description = "ID of the MinIO S3 bucket"
  value       = aws_s3_bucket.minio_placeholder.id
}

output "minio_bucket_arn" {
  description = "ARN of the MinIO S3 bucket"
  value       = aws_s3_bucket.minio_placeholder.arn
}

output "minio_bucket_domain_name" {
  description = "Domain name of the MinIO S3 bucket"
  value       = aws_s3_bucket.minio_placeholder.bucket_domain_name
}
