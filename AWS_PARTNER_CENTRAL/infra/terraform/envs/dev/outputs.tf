output "vpc_id" {
  description = "VPC ID"
  value       = module.core_network.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.core_network.private_subnet_ids
}

output "event_bus_name" {
  description = "EventBridge bus name"
  value       = module.eventing.bus_name
}

output "event_bus_arn" {
  description = "EventBridge bus ARN"
  value       = module.eventing.bus_arn
}

output "db_endpoint" {
  description = "Aurora PostgreSQL endpoint"
  value       = module.operational_db.endpoint
}

output "lake_bucket_name" {
  description = "S3 data lake bucket name"
  value       = module.data_lake.bucket_name
}

output "lake_bucket_arn" {
  description = "S3 data lake bucket ARN"
  value       = module.data_lake.bucket_arn
}

output "redshift_workgroup" {
  description = "Redshift Serverless workgroup name"
  value       = module.warehouse.workgroup_name
}

output "partnercentral_policy_arn" {
  description = "Partner Central IAM policy ARN"
  value       = module.partnercentral_access.policy_arn
}

output "marketplace_policy_arn" {
  description = "Marketplace IAM policy ARN"
  value       = module.marketplace_access.policy_arn
}
