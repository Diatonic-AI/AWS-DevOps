# Outputs for MinIO Standalone Infrastructure

# S3 Bucket Information
output "s3_bucket_names" {
  description = "Map of S3 bucket names created for MinIO"
  value = {
    for key, bucket in aws_s3_bucket.minio_buckets : key => bucket.id
  }
}

output "s3_bucket_arns" {
  description = "Map of S3 bucket ARNs created for MinIO"
  value = {
    for key, bucket in aws_s3_bucket.minio_buckets : key => bucket.arn
  }
}

output "primary_data_bucket" {
  description = "Primary MinIO data bucket information"
  value = {
    name = aws_s3_bucket.minio_buckets["minio-data"].id
    arn  = aws_s3_bucket.minio_buckets["minio-data"].arn
    region = aws_s3_bucket.minio_buckets["minio-data"].region
  }
}

output "backup_bucket" {
  description = "MinIO backup bucket information"
  value = {
    name = aws_s3_bucket.minio_buckets["minio-backups"].id
    arn  = aws_s3_bucket.minio_buckets["minio-backups"].arn
    region = aws_s3_bucket.minio_buckets["minio-backups"].region
  }
}

# IAM Information
output "iam_user_name" {
  description = "IAM username for MinIO"
  value       = aws_iam_user.minio_user.name
}

output "iam_user_arn" {
  description = "IAM user ARN for MinIO"
  value       = aws_iam_user.minio_user.arn
}

output "aws_access_key_id" {
  description = "AWS Access Key ID for MinIO"
  value       = aws_iam_access_key.minio_user.id
  sensitive   = true
}

output "aws_secret_access_key" {
  description = "AWS Secret Access Key for MinIO"
  value       = aws_iam_access_key.minio_user.secret
  sensitive   = true
}

# CloudWatch Information
output "cloudwatch_log_group" {
  description = "CloudWatch log group for MinIO"
  value = {
    name = aws_cloudwatch_log_group.minio_logs.name
    arn  = aws_cloudwatch_log_group.minio_logs.arn
  }
}

# Configuration for MinIO Gateway Setup
output "minio_s3_gateway_config" {
  description = "Configuration values needed to set up MinIO as S3 gateway"
  value = {
    aws_region           = var.aws_region
    primary_bucket       = aws_s3_bucket.minio_buckets["minio-data"].id
    backup_bucket        = aws_s3_bucket.minio_buckets["minio-backups"].id
    uploads_bucket       = aws_s3_bucket.minio_buckets["minio-uploads"].id
    logs_bucket         = aws_s3_bucket.minio_buckets["minio-logs"].id
    iam_user            = aws_iam_user.minio_user.name
    cloudwatch_log_group = aws_cloudwatch_log_group.minio_logs.name
  }
  sensitive = false
}

# Environment file content for MinIO
output "minio_environment_config" {
  description = "Environment configuration for MinIO service"
  value = {
    MINIO_ROOT_USER              = var.minio_root_user
    MINIO_ROOT_PASSWORD          = var.minio_root_password
    AWS_REGION                   = var.aws_region
    AWS_ACCESS_KEY_ID            = aws_iam_access_key.minio_user.id
    AWS_SECRET_ACCESS_KEY        = aws_iam_access_key.minio_user.secret
    MINIO_STORAGE_CLASS_STANDARD = "s3:${aws_s3_bucket.minio_buckets["minio-data"].id}"
    MINIO_BROWSER                = "on"
    MINIO_CONSOLE_ADDRESS        = ":9001"
  }
  sensitive = true
}

# Summary information
output "deployment_summary" {
  description = "Summary of MinIO deployment resources"
  value = {
    project_name        = var.project_name
    environment         = var.environment
    aws_region         = var.aws_region
    total_buckets      = length(aws_s3_bucket.minio_buckets)
    bucket_names       = [for bucket in aws_s3_bucket.minio_buckets : bucket.id]
    iam_user           = aws_iam_user.minio_user.name
    created_at         = timestamp()
  }
}

# Instructions for next steps
output "next_steps" {
  description = "Instructions for configuring MinIO with these AWS resources"
  sensitive   = true
  value = <<-EOF
    
    Next Steps to Configure MinIO:
    
    1. Export AWS credentials to MinIO LXD container:
       AWS_ACCESS_KEY_ID="${aws_iam_access_key.minio_user.id}"
       AWS_SECRET_ACCESS_KEY="${aws_iam_access_key.minio_user.secret}"
       AWS_REGION="${var.aws_region}"
    
    2. Configure MinIO to use S3 backend:
       Primary Bucket: ${aws_s3_bucket.minio_buckets["minio-data"].id}
       Region: ${var.aws_region}
    
    3. Update MinIO service configuration in LXD container
    
    4. Restart MinIO service
    
    5. Verify connectivity and test operations
    
  EOF
}

# Resource IDs for reference
output "resource_ids" {
  description = "Important resource IDs for reference"
  value = {
    random_suffix        = random_id.suffix.hex
    iam_policy_arn      = aws_iam_policy.minio_s3_policy.arn
    log_group_name      = aws_cloudwatch_log_group.minio_logs.name
  }
}
