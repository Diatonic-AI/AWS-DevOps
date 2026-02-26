# MMP Toledo Sync - Root Outputs

# ============================================================================
# LAMBDA OUTPUTS
# ============================================================================

output "lambda_function_arn" {
  description = "ARN of the MMP Toledo sync Lambda function"
  value       = module.mmp_toledo_sync.lambda_function_arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = module.mmp_toledo_sync.lambda_function_name
}

output "lambda_invoke_arn" {
  description = "Invoke ARN for testing"
  value       = module.mmp_toledo_sync.lambda_function_invoke_arn
}

# ============================================================================
# SECRETS OUTPUTS
# ============================================================================

output "supabase_secret_arn" {
  description = "ARN of the Supabase credentials secret"
  value       = module.mmp_toledo_sync.supabase_secret_arn
}

# ============================================================================
# DEAD LETTER QUEUE
# ============================================================================

output "dlq_url" {
  description = "URL of the dead letter queue"
  value       = module.mmp_toledo_sync.dlq_url
}

output "dlq_arn" {
  description = "ARN of the dead letter queue"
  value       = module.mmp_toledo_sync.dlq_arn
}

# ============================================================================
# CLOUDWATCH
# ============================================================================

output "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  value       = module.mmp_toledo_sync.cloudwatch_log_group_name
}

# ============================================================================
# EVENT SOURCE MAPPINGS
# ============================================================================

output "event_source_mappings" {
  description = "DynamoDB stream event source mappings"
  value       = module.mmp_toledo_sync.event_source_mappings
}

# ============================================================================
# CONFIGURATION SUMMARY
# ============================================================================

output "configuration_summary" {
  description = "Summary of the deployment configuration"
  value       = module.mmp_toledo_sync.configuration_summary
}

output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown"
  value       = module.mmp_toledo_sync.estimated_monthly_cost
}

# ============================================================================
# DEPLOYMENT INFO
# ============================================================================

output "deployment_info" {
  description = "Deployment information and next steps"
  value = {
    status           = "Deployed successfully"
    environment      = var.environment
    region           = var.aws_region
    supabase_project = var.supabase_url
    webhook_endpoint = var.supabase_webhook_url

    next_steps = [
      "1. Verify Lambda is receiving DynamoDB stream events",
      "2. Check CloudWatch logs for sync activity",
      "3. Query Supabase tables to verify data is syncing",
      "4. Monitor DLQ for failed messages"
    ]

    useful_commands = {
      view_logs       = "aws logs tail ${module.mmp_toledo_sync.cloudwatch_log_group_name} --follow"
      invoke_lambda   = "aws lambda invoke --function-name ${module.mmp_toledo_sync.lambda_function_name} --payload '{}' response.json"
      check_dlq_depth = "aws sqs get-queue-attributes --queue-url ${module.mmp_toledo_sync.dlq_url} --attribute-names ApproximateNumberOfMessages"
    }
  }
}
