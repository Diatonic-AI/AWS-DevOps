output "secrets_key_arn" {
  description = "Secrets Manager KMS key ARN"
  value       = aws_kms_key.secrets.arn
}

output "lake_key_arn" {
  description = "Data Lake KMS key ARN"
  value       = aws_kms_key.lake.arn
}

output "db_key_arn" {
  description = "Database KMS key ARN"
  value       = aws_kms_key.db.arn
}

output "warehouse_key_arn" {
  description = "Warehouse KMS key ARN"
  value       = aws_kms_key.warehouse.arn
}
