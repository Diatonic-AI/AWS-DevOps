# MMP Toledo Sync Module Outputs

# ============================================================================
# LAMBDA FUNCTION OUTPUTS
# ============================================================================

output "lambda_function_arn" {
  description = "ARN of the MMP Toledo sync Lambda function"
  value       = aws_lambda_function.sync.arn
}

output "lambda_function_name" {
  description = "Name of the MMP Toledo sync Lambda function"
  value       = aws_lambda_function.sync.function_name
}

output "lambda_function_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  value       = aws_lambda_function.sync.invoke_arn
}

output "lambda_function_version" {
  description = "Version of the Lambda function"
  value       = aws_lambda_function.sync.version
}

output "lambda_alias_arn" {
  description = "ARN of the live Lambda alias"
  value       = aws_lambda_alias.live.arn
}

# ============================================================================
# IAM OUTPUTS
# ============================================================================

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.arn
}

output "lambda_execution_role_name" {
  description = "Name of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.name
}

# ============================================================================
# SECRETS OUTPUTS
# ============================================================================

output "supabase_secret_arn" {
  description = "ARN of the Supabase credentials secret"
  value       = aws_secretsmanager_secret.supabase_credentials.arn
}

output "supabase_secret_name" {
  description = "Name of the Supabase credentials secret"
  value       = aws_secretsmanager_secret.supabase_credentials.name
}

# ============================================================================
# DEAD LETTER QUEUE OUTPUTS
# ============================================================================

output "dlq_arn" {
  description = "ARN of the dead letter queue"
  value       = aws_sqs_queue.dlq.arn
}

output "dlq_url" {
  description = "URL of the dead letter queue"
  value       = aws_sqs_queue.dlq.url
}

output "dlq_name" {
  description = "Name of the dead letter queue"
  value       = aws_sqs_queue.dlq.name
}

# ============================================================================
# CLOUDWATCH OUTPUTS
# ============================================================================

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda.arn
}

# ============================================================================
# EVENT SOURCE MAPPING OUTPUTS
# ============================================================================

output "event_source_mappings" {
  description = "Map of DynamoDB stream event source mappings"
  value = {
    for k, v in aws_lambda_event_source_mapping.dynamodb_streams : k => {
      uuid                   = v.uuid
      state                  = v.state
      function_arn          = v.function_arn
      event_source_arn      = v.event_source_arn
      batch_size            = v.batch_size
      starting_position     = v.starting_position
    }
  }
}

# ============================================================================
# COST ESTIMATION OUTPUTS
# ============================================================================

output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown"
  value = {
    description = "Cost estimates (within AWS Free Tier for low volume)"
    lambda = {
      architecture = "ARM64 (34% cheaper than x86)"
      memory_mb    = var.lambda_memory_size
      note         = "Free tier: 400,000 GB-seconds/month"
    }
    dynamodb_streams = {
      note = "FREE - included with DynamoDB"
    }
    secrets_manager = {
      estimated = "$0.40/month"
      note      = "One secret for Supabase credentials"
    }
    cloudwatch_logs = {
      retention_days = var.log_retention_days
      estimated      = "$0.00-$0.50/month"
      note           = "Depends on log volume"
    }
    sqs_dlq = {
      estimated = "$0.00/month"
      note      = "Free tier: 1M requests/month"
    }
    total_estimated = "$0.40-$1.00/month (most within free tier)"
  }
}

# ============================================================================
# CONFIGURATION SUMMARY
# ============================================================================

output "configuration_summary" {
  description = "Summary of sync configuration"
  value = {
    environment              = var.environment
    lambda_memory_mb         = var.lambda_memory_size
    lambda_timeout_sec       = var.lambda_timeout
    batch_size               = var.batch_size
    batching_window_sec      = var.batching_window_seconds
    reserved_concurrency     = var.reserved_concurrent_executions
    max_retries              = var.max_retries
    log_retention_days       = var.log_retention_days
    monitoring_enabled       = var.enable_monitoring
    dynamodb_streams_count   = length(var.dynamodb_streams)
    supabase_webhook_url     = var.supabase_webhook_url
  }
}
