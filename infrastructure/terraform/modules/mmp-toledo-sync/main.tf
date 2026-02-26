# MMP Toledo DynamoDB to Supabase Sync Module
# Cost-Optimized Architecture: DynamoDB Streams → Lambda (ARM64) → Supabase Edge Function
#
# Cost Analysis:
# - DynamoDB Streams: FREE (included with DynamoDB)
# - Lambda (ARM64, 128MB): ~$0.0000001667/100ms = $0.00/month at low volume
# - No API Gateway: Saves $3.50/million requests
# - Secrets Manager: $0.40/month per secret
# - CloudWatch Logs: ~$0.50/GB ingested
# Total Estimated: $0.40-$1.00/month (within free tier for most cases)

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

# Random suffix for unique naming
resource "random_id" "suffix" {
  byte_length = 4
}

# ============================================================================
# SECRETS MANAGEMENT
# ============================================================================

# Store Supabase credentials securely
resource "aws_secretsmanager_secret" "supabase_credentials" {
  name        = "${var.project_prefix}-mmp-toledo-supabase-${var.environment}-${random_id.suffix.hex}"
  description = "Supabase credentials for MMP Toledo sync"

  recovery_window_in_days = var.environment == "prod" ? 30 : 0

  tags = merge(var.default_tags, {
    Name      = "MMP Toledo Supabase Credentials"
    Component = "mmp-toledo-sync"
  })
}

resource "aws_secretsmanager_secret_version" "supabase_credentials" {
  secret_id = aws_secretsmanager_secret.supabase_credentials.id
  secret_string = jsonencode({
    SUPABASE_URL          = var.supabase_url
    SUPABASE_ANON_KEY     = var.supabase_anon_key
    SUPABASE_SERVICE_KEY  = var.supabase_service_role_key
    SUPABASE_WEBHOOK_URL  = var.supabase_webhook_url
  })
}

# ============================================================================
# IAM ROLES AND POLICIES
# ============================================================================

# Lambda execution role
resource "aws_iam_role" "lambda_execution" {
  name = "${var.project_prefix}-mmp-toledo-sync-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.default_tags, {
    Name = "MMP Toledo Sync Lambda Role"
  })
}

# Lambda execution policy - minimal permissions for cost optimization
resource "aws_iam_policy" "lambda_execution" {
  name        = "${var.project_prefix}-mmp-toledo-sync-policy-${var.environment}"
  description = "IAM policy for MMP Toledo DynamoDB to Supabase sync Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        # CloudWatch Logs - required for debugging
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_prefix}-mmp-toledo-sync-${var.environment}*"
        },
        # Secrets Manager - retrieve Supabase credentials
        {
          Effect = "Allow"
          Action = [
            "secretsmanager:GetSecretValue"
          ]
          Resource = aws_secretsmanager_secret.supabase_credentials.arn
        },
        # SQS Dead Letter Queue
        {
          Effect = "Allow"
          Action = [
            "sqs:SendMessage"
          ]
          Resource = aws_sqs_queue.dlq.arn
        }
      ],
      # DynamoDB Streams - only if streams are configured
      length(var.dynamodb_table_stream_arns) > 0 ? [
        {
          Effect = "Allow"
          Action = [
            "dynamodb:GetRecords",
            "dynamodb:GetShardIterator",
            "dynamodb:DescribeStream",
            "dynamodb:ListStreams"
          ]
          Resource = var.dynamodb_table_stream_arns
        }
      ] : [],
      # DynamoDB Tables - only if tables are configured
      length(var.dynamodb_table_arns) > 0 ? [
        {
          Effect = "Allow"
          Action = [
            "dynamodb:GetItem",
            "dynamodb:Query",
            "dynamodb:Scan"
          ]
          Resource = var.dynamodb_table_arns
        }
      ] : []
    )
  })

  tags = var.default_tags
}

resource "aws_iam_role_policy_attachment" "lambda_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.lambda_execution.arn
}

# ============================================================================
# DEAD LETTER QUEUE (for failed messages)
# ============================================================================

resource "aws_sqs_queue" "dlq" {
  name                       = "${var.project_prefix}-mmp-toledo-sync-dlq-${var.environment}"
  message_retention_seconds  = 1209600 # 14 days
  visibility_timeout_seconds = 60

  # SQS is very cheap - no encryption to minimize costs in dev
  # Enable KMS encryption in production
  sqs_managed_sse_enabled = var.environment == "prod" ? false : true

  tags = merge(var.default_tags, {
    Name      = "MMP Toledo Sync DLQ"
    Component = "mmp-toledo-sync"
  })
}

# ============================================================================
# LAMBDA FUNCTION
# ============================================================================

# CloudWatch Log Group with retention for cost optimization
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_prefix}-mmp-toledo-sync-${var.environment}"
  retention_in_days = var.log_retention_days # Default 7 days to minimize costs

  tags = merge(var.default_tags, {
    Name = "MMP Toledo Sync Lambda Logs"
  })
}

# Package Lambda code
data "archive_file" "lambda" {
  type        = "zip"
  output_path = "${path.module}/lambda-deployment.zip"

  source {
    content  = local.lambda_code
    filename = "index.mjs"
  }
}

# Lambda function - ARM64 for 34% cost savings
resource "aws_lambda_function" "sync" {
  function_name = "${var.project_prefix}-mmp-toledo-sync-${var.environment}"
  description   = "Syncs MMP Toledo DynamoDB records to Supabase in real-time"

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  handler = "index.handler"
  runtime = "nodejs20.x"

  # Cost optimization: ARM64 is 34% cheaper than x86_64
  architectures = ["arm64"]

  # Minimal memory - sufficient for HTTP calls
  memory_size = var.lambda_memory_size
  timeout     = var.lambda_timeout

  role = aws_iam_role.lambda_execution.arn

  # Dead letter queue for failed invocations
  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }

  environment {
    variables = {
      SUPABASE_SECRET_ARN = aws_secretsmanager_secret.supabase_credentials.arn
      AWS_REGION_NAME     = var.aws_region
      ENVIRONMENT         = var.environment
      LOG_LEVEL           = var.environment == "prod" ? "INFO" : "DEBUG"
      # Retry configuration
      MAX_RETRIES         = tostring(var.max_retries)
      RETRY_DELAY_MS      = tostring(var.retry_delay_ms)
    }
  }

  # Reserved concurrent executions - prevents runaway costs
  reserved_concurrent_executions = var.reserved_concurrent_executions

  tags = merge(var.default_tags, {
    Name      = "MMP Toledo Sync Lambda"
    Component = "mmp-toledo-sync"
    Runtime   = "nodejs20.x"
    Arch      = "arm64"
  })

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.lambda_execution
  ]
}

# Lambda alias for versioning
resource "aws_lambda_alias" "live" {
  name             = "live"
  description      = "Live alias for MMP Toledo sync"
  function_name    = aws_lambda_function.sync.function_name
  function_version = aws_lambda_function.sync.version
}

# ============================================================================
# DYNAMODB STREAM EVENT SOURCE MAPPINGS
# ============================================================================

# Create event source mapping for each DynamoDB table stream
resource "aws_lambda_event_source_mapping" "dynamodb_streams" {
  for_each = var.dynamodb_streams

  event_source_arn = each.value.stream_arn
  function_name    = aws_lambda_function.sync.arn

  # Start from the most recent record to avoid reprocessing
  starting_position = "LATEST"

  # Batch configuration for cost optimization
  batch_size                         = var.batch_size
  maximum_batching_window_in_seconds = var.batching_window_seconds

  # Parallelization - 1 concurrent batch per shard
  parallelization_factor = 1

  # Error handling
  maximum_retry_attempts       = var.stream_max_retries
  maximum_record_age_in_seconds = 3600 # 1 hour max age

  # Failure destination - send to DLQ
  destination_config {
    on_failure {
      destination_arn = aws_sqs_queue.dlq.arn
    }
  }

  # Filter patterns to reduce invocations (cost optimization)
  dynamic "filter_criteria" {
    for_each = each.value.filter_pattern != null ? [1] : []
    content {
      filter {
        pattern = each.value.filter_pattern
      }
    }
  }

  depends_on = [aws_lambda_function.sync]
}

# ============================================================================
# CLOUDWATCH ALARMS (Optional - for monitoring)
# ============================================================================

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.project_prefix}-mmp-toledo-sync-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "MMP Toledo sync Lambda errors exceeded threshold"

  dimensions = {
    FunctionName = aws_lambda_function.sync.function_name
  }

  alarm_actions = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  tags = var.default_tags
}

resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.project_prefix}-mmp-toledo-sync-dlq-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "MMP Toledo sync DLQ has unprocessed messages"

  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }

  alarm_actions = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  tags = var.default_tags
}

# ============================================================================
# DATA SOURCES
# ============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ============================================================================
# LOCAL VALUES
# ============================================================================

locals {
  # Lambda function code - inline for simplicity
  lambda_code = <<-EOJS
// MMP Toledo DynamoDB to Supabase Sync Lambda
// Cost-Optimized: ARM64, 128MB, no VPC
// Runtime: Node.js 20.x ESM

import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";

const secretsClient = new SecretsManagerClient({ region: process.env.AWS_REGION_NAME });

let cachedSecrets = null;
let secretsCacheTime = 0;
const CACHE_TTL = 300000; // 5 minutes

// Get Supabase credentials from Secrets Manager (cached)
async function getSupabaseCredentials() {
  const now = Date.now();
  if (cachedSecrets && (now - secretsCacheTime) < CACHE_TTL) {
    return cachedSecrets;
  }

  const command = new GetSecretValueCommand({
    SecretId: process.env.SUPABASE_SECRET_ARN
  });

  const response = await secretsClient.send(command);
  cachedSecrets = JSON.parse(response.SecretString);
  secretsCacheTime = now;
  return cachedSecrets;
}

// Convert DynamoDB item format to plain object
function convertDynamoDBItem(item) {
  if (!item || typeof item !== 'object') return item;

  const result = {};
  for (const [key, value] of Object.entries(item)) {
    if (typeof value === 'object' && value !== null) {
      if ('S' in value) result[key] = value.S;
      else if ('N' in value) result[key] = parseFloat(value.N);
      else if ('BOOL' in value) result[key] = value.BOOL;
      else if ('NULL' in value) result[key] = null;
      else if ('B' in value) result[key] = value.B;
      else if ('SS' in value) result[key] = value.SS;
      else if ('NS' in value) result[key] = value.NS.map(n => parseFloat(n));
      else if ('BS' in value) result[key] = value.BS;
      else if ('M' in value) result[key] = convertDynamoDBItem(value.M);
      else if ('L' in value) result[key] = value.L.map(item => convertDynamoDBItem({ temp: item }).temp);
      else result[key] = value;
    }
  }
  return result;
}

// Extract table name from DynamoDB stream ARN
function extractTableName(arn) {
  const match = arn.match(/table\/([^\/]+)/);
  return match ? match[1] : null;
}

// Map DynamoDB table names to Supabase table names
function mapTableName(dynamoTableName) {
  const mapping = {
    // MMP Toledo actual production tables
    'Lead-sqiqbtbugvfabolqwdt4rz3dla-NONE': 'mmp_toledo_leads',
    'Lead-h6a66mxndnhc7h3o4kldil67oa-NONE': 'mmp_toledo_leads',
    'Lead-sfyatimxznhd3nybi6mcbg5ipq-NONE': 'mmp_toledo_leads',
    'Lead-x5u6a7nejrcfbjj6qld46eamai-NONE': 'mmp_toledo_leads',
    'Lead-xllvnlnajffmznanpuyhq3pl6i-NONE': 'mmp_toledo_leads',
    'toledo-consulting-dashboard-data': 'toledo_dashboard',
    // Legacy table names
    'mmp-toledo-leads-prod': 'mmp_toledo_leads',
    'mmp-toledo-otp-prod': 'mmp_toledo_otp',
    // Firespring tables
    'firespring-backdoor-actions-dev': 'firespring_actions',
    'firespring-backdoor-extraction-jobs-dev': 'firespring_extraction_jobs',
    'firespring-backdoor-network-state-dev': 'firespring_network_state',
    'firespring-backdoor-searches-dev': 'firespring_searches',
    'firespring-backdoor-segments-dev': 'firespring_segments',
    'firespring-backdoor-traffic-sources-dev': 'firespring_traffic_sources',
    'firespring-backdoor-visitors-dev': 'firespring_visitors'
  };
  return mapping[dynamoTableName] || dynamoTableName.replace(/-/g, '_').toLowerCase();
}

// Call Supabase webhook with retry logic
async function callSupabaseWebhook(webhookUrl, apiKey, payload, maxRetries = 3) {
  const retryDelay = parseInt(process.env.RETRY_DELAY_MS) || 1000;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const response = await fetch(webhookUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + apiKey,
          'X-Source': 'aws-lambda-dynamodb-stream'
        },
        body: JSON.stringify(payload)
      });

      if (!response.ok) {
        const errorText = await response.text();
        throw new Error('HTTP ' + response.status + ': ' + errorText);
      }

      return await response.json();
    } catch (error) {
      console.error('Attempt ' + attempt + ' failed:', error.message);
      if (attempt === maxRetries) throw error;
      await new Promise(r => setTimeout(r, retryDelay * attempt));
    }
  }
}

// Main Lambda handler
export async function handler(event, context) {
  console.log('Processing', event.Records?.length || 0, 'DynamoDB stream records');

  const credentials = await getSupabaseCredentials();
  const results = [];
  const errors = [];

  for (const record of event.Records || []) {
    try {
      const { eventName, eventSourceARN, dynamodb } = record;

      if (!dynamodb) {
        console.warn('No dynamodb data in record:', record.eventID);
        continue;
      }

      const tableName = extractTableName(eventSourceARN);
      const supabaseTable = mapTableName(tableName);

      const newImage = dynamodb.NewImage ? convertDynamoDBItem(dynamodb.NewImage) : null;
      const oldImage = dynamodb.OldImage ? convertDynamoDBItem(dynamodb.OldImage) : null;

      let action;
      switch (eventName) {
        case 'INSERT': action = 'INSERT'; break;
        case 'MODIFY': action = 'UPDATE'; break;
        case 'REMOVE': action = 'DELETE'; break;
        default:
          console.warn('Unknown event type:', eventName);
          continue;
      }

      const payload = {
        table: supabaseTable,
        action: action,
        data: newImage || oldImage,
        metadata: {
          eventId: record.eventID,
          sequenceNumber: dynamodb.SequenceNumber,
          approximateCreationDateTime: dynamodb.ApproximateCreationDateTime,
          dynamoTableName: tableName
        }
      };

      const result = await callSupabaseWebhook(
        credentials.SUPABASE_WEBHOOK_URL,
        credentials.SUPABASE_ANON_KEY,  // Anon key for function invocation - function uses its own service role key for DB
        payload,
        parseInt(process.env.MAX_RETRIES) || 3
      );

      results.push({
        eventId: record.eventID,
        table: supabaseTable,
        action: action,
        success: true
      });

      console.log('Synced record:', record.eventID, 'to', supabaseTable);

    } catch (error) {
      console.error('Error processing record:', record.eventID, error);
      errors.push({
        eventId: record.eventID,
        error: error.message
      });
    }
  }

  const response = {
    processed: results.length,
    errors: errors.length,
    results: results,
    errorDetails: errors
  };

  // If any errors, throw to trigger DLQ
  if (errors.length > 0 && errors.length === event.Records?.length) {
    throw new Error('All records failed: ' + JSON.stringify(errors));
  }

  console.log('Processing complete:', response);
  return response;
}
EOJS
}
