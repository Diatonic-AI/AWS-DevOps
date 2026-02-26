# Firespring DynamoDB Sync - us-east-1 Region
# This configuration syncs Firespring tables from us-east-1 to Supabase

# ============================================================================
# PROVIDER FOR US-EAST-1
# ============================================================================

provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = "MMP-Toledo"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Component   = "firespring-supabase-sync"
      CostCenter  = "mmp-toledo"
    }
  }
}

# ============================================================================
# DATA SOURCES - Firespring DynamoDB Tables
# ============================================================================

data "aws_dynamodb_table" "firespring_actions" {
  provider = aws.us_east_1
  count    = var.enable_firespring_sync ? 1 : 0
  name     = "firespring-backdoor-actions-dev"
}

data "aws_dynamodb_table" "firespring_extraction_jobs" {
  provider = aws.us_east_1
  count    = var.enable_firespring_sync ? 1 : 0
  name     = "firespring-backdoor-extraction-jobs-dev"
}

data "aws_dynamodb_table" "firespring_network_state" {
  provider = aws.us_east_1
  count    = var.enable_firespring_sync ? 1 : 0
  name     = "firespring-backdoor-network-state-dev"
}

data "aws_dynamodb_table" "firespring_searches" {
  provider = aws.us_east_1
  count    = var.enable_firespring_sync ? 1 : 0
  name     = "firespring-backdoor-searches-dev"
}

data "aws_dynamodb_table" "firespring_segments" {
  provider = aws.us_east_1
  count    = var.enable_firespring_sync ? 1 : 0
  name     = "firespring-backdoor-segments-dev"
}

data "aws_dynamodb_table" "firespring_traffic_sources" {
  provider = aws.us_east_1
  count    = var.enable_firespring_sync ? 1 : 0
  name     = "firespring-backdoor-traffic-sources-dev"
}

data "aws_dynamodb_table" "firespring_visitors" {
  provider = aws.us_east_1
  count    = var.enable_firespring_sync ? 1 : 0
  name     = "firespring-backdoor-visitors-dev"
}

# ============================================================================
# LOCAL VALUES FOR FIRESPRING
# ============================================================================

locals {
  firespring_tables = var.enable_firespring_sync ? {
    "firespring-actions" = {
      table_arn  = data.aws_dynamodb_table.firespring_actions[0].arn
      stream_arn = data.aws_dynamodb_table.firespring_actions[0].stream_arn
    }
    "firespring-extraction-jobs" = {
      table_arn  = data.aws_dynamodb_table.firespring_extraction_jobs[0].arn
      stream_arn = data.aws_dynamodb_table.firespring_extraction_jobs[0].stream_arn
    }
    "firespring-network-state" = {
      table_arn  = data.aws_dynamodb_table.firespring_network_state[0].arn
      stream_arn = data.aws_dynamodb_table.firespring_network_state[0].stream_arn
    }
    "firespring-searches" = {
      table_arn  = data.aws_dynamodb_table.firespring_searches[0].arn
      stream_arn = data.aws_dynamodb_table.firespring_searches[0].stream_arn
    }
    "firespring-segments" = {
      table_arn  = data.aws_dynamodb_table.firespring_segments[0].arn
      stream_arn = data.aws_dynamodb_table.firespring_segments[0].stream_arn
    }
    "firespring-traffic-sources" = {
      table_arn  = data.aws_dynamodb_table.firespring_traffic_sources[0].arn
      stream_arn = data.aws_dynamodb_table.firespring_traffic_sources[0].stream_arn
    }
    "firespring-visitors" = {
      table_arn  = data.aws_dynamodb_table.firespring_visitors[0].arn
      stream_arn = data.aws_dynamodb_table.firespring_visitors[0].stream_arn
    }
  } : {}

  firespring_table_arns  = var.enable_firespring_sync ? [for k, v in local.firespring_tables : v.table_arn] : []
  firespring_stream_arns = var.enable_firespring_sync ? [for k, v in local.firespring_tables : v.stream_arn] : []
}

# ============================================================================
# IAM ROLE FOR FIRESPRING LAMBDA
# ============================================================================

resource "aws_iam_role" "firespring_sync_lambda" {
  count    = var.enable_firespring_sync ? 1 : 0
  provider = aws.us_east_1
  name     = "${var.project_name}-firespring-sync-${var.environment}"

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
}

resource "aws_iam_role_policy" "firespring_sync_lambda" {
  count    = var.enable_firespring_sync ? 1 : 0
  provider = aws.us_east_1
  name     = "${var.project_name}-firespring-sync-policy-${var.environment}"
  role     = aws_iam_role.firespring_sync_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-firespring-sync-${var.environment}*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:DescribeStream",
          "dynamodb:ListStreams"
        ]
        Resource = local.firespring_stream_arns
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = local.firespring_table_arns
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = module.mmp_toledo_sync.supabase_secret_arn
      }
    ]
  })
}

# ============================================================================
# CLOUDWATCH LOG GROUP
# ============================================================================

resource "aws_cloudwatch_log_group" "firespring_sync" {
  count             = var.enable_firespring_sync ? 1 : 0
  provider          = aws.us_east_1
  name              = "/aws/lambda/${var.project_name}-firespring-sync-${var.environment}"
  retention_in_days = var.log_retention_days
}

# ============================================================================
# LAMBDA FUNCTION FOR FIRESPRING SYNC
# ============================================================================

data "archive_file" "firespring_sync_lambda" {
  count       = var.enable_firespring_sync ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/firespring-sync-lambda.zip"

  source {
    content  = <<-EOF
// Firespring DynamoDB to Supabase Sync Lambda (us-east-1)
// This Lambda processes DynamoDB streams and forwards to Supabase Edge Function

import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';

const secretsClient = new SecretsManagerClient({ region: 'us-east-2' });
const SECRET_ARN = '${module.mmp_toledo_sync.supabase_secret_arn}';

let cachedCredentials = null;

async function getSupabaseCredentials() {
  if (cachedCredentials) return cachedCredentials;

  const command = new GetSecretValueCommand({ SecretId: SECRET_ARN });
  const response = await secretsClient.send(command);
  cachedCredentials = JSON.parse(response.SecretString);
  return cachedCredentials;
}

function extractTableName(arn) {
  const match = arn.match(/table\/([^\/]+)/);
  return match ? match[1] : null;
}

function mapTableName(dynamoTableName) {
  const mapping = {
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

function convertDynamoDBItem(item) {
  if (!item || typeof item !== 'object') return item;
  const result = {};
  for (const [key, value] of Object.entries(item)) {
    if (typeof value === 'object' && value !== null) {
      if ('S' in value) result[key] = value.S;
      else if ('N' in value) result[key] = parseFloat(value.N);
      else if ('BOOL' in value) result[key] = value.BOOL;
      else if ('NULL' in value) result[key] = null;
      else if ('SS' in value) result[key] = value.SS;
      else if ('NS' in value) result[key] = value.NS.map(n => parseFloat(n));
      else if ('M' in value) result[key] = convertDynamoDBItem(value.M);
      else if ('L' in value) result[key] = value.L.map(item => convertDynamoDBItem({ temp: item }).temp);
      else result[key] = value;
    }
  }
  return result;
}

async function callSupabaseWebhook(webhookUrl, apiKey, payload, maxRetries = 3) {
  const retryDelay = 1000;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const response = await fetch(webhookUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + apiKey,
          'X-Source': 'aws-lambda-firespring-sync'
        },
        body: JSON.stringify(payload)
      });

      if (response.ok) {
        return await response.json();
      }

      const errorText = await response.text();
      if (attempt === maxRetries) {
        throw new Error('HTTP ' + response.status + ': ' + errorText);
      }
      await new Promise(r => setTimeout(r, retryDelay * attempt));
    } catch (error) {
      if (attempt === maxRetries) throw error;
      await new Promise(r => setTimeout(r, retryDelay * attempt));
    }
  }
}

export const handler = async (event) => {
  console.log('Processing', event.Records?.length || 0, 'Firespring stream records');

  const credentials = await getSupabaseCredentials();
  const results = [];
  const errors = [];

  for (const record of event.Records || []) {
    try {
      const { eventName, eventSourceARN, dynamodb } = record;
      if (!dynamodb) continue;

      const tableName = extractTableName(eventSourceARN);
      const supabaseTable = mapTableName(tableName);
      const newImage = dynamodb.NewImage ? convertDynamoDBItem(dynamodb.NewImage) : null;
      const oldImage = dynamodb.OldImage ? convertDynamoDBItem(dynamodb.OldImage) : null;

      let action;
      switch (eventName) {
        case 'INSERT': action = 'INSERT'; break;
        case 'MODIFY': action = 'UPDATE'; break;
        case 'REMOVE': action = 'DELETE'; break;
        default: continue;
      }

      const payload = {
        table: supabaseTable,
        action: action,
        data: newImage || oldImage,
        metadata: {
          eventId: record.eventID,
          sequenceNumber: dynamodb.SequenceNumber,
          dynamoTableName: tableName,
          source: 'firespring-sync'
        }
      };

      await callSupabaseWebhook(
        credentials.SUPABASE_WEBHOOK_URL,
        credentials.SUPABASE_ANON_KEY,
        payload
      );

      results.push({ eventId: record.eventID, table: supabaseTable, success: true });
    } catch (error) {
      console.error('Error processing record:', record.eventID, error);
      errors.push({ eventId: record.eventID, error: error.message });
    }
  }

  console.log('Complete:', results.length, 'success,', errors.length, 'errors');

  if (errors.length > 0 && results.length === 0) {
    throw new Error('All records failed: ' + JSON.stringify(errors));
  }

  return { processed: results.length, errors: errors.length, results, errorDetails: errors };
};
EOF
    filename = "index.mjs"
  }
}

resource "aws_lambda_function" "firespring_sync" {
  count            = var.enable_firespring_sync ? 1 : 0
  provider         = aws.us_east_1
  function_name    = "${var.project_name}-firespring-sync-${var.environment}"
  role             = aws_iam_role.firespring_sync_lambda[0].arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  architectures    = ["arm64"]
  memory_size      = var.lambda_memory_size
  timeout          = var.lambda_timeout
  filename         = data.archive_file.firespring_sync_lambda[0].output_path
  source_code_hash = data.archive_file.firespring_sync_lambda[0].output_base64sha256

  reserved_concurrent_executions = var.reserved_concurrent_executions

  environment {
    variables = {
      SUPABASE_SECRET_ARN = module.mmp_toledo_sync.supabase_secret_arn
      MAX_RETRIES         = tostring(var.max_retries)
      RETRY_DELAY_MS      = tostring(var.retry_delay_ms)
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.firespring_sync,
    aws_iam_role_policy.firespring_sync_lambda
  ]
}

# ============================================================================
# EVENT SOURCE MAPPINGS - Connect Lambda to DynamoDB Streams
# ============================================================================

resource "aws_lambda_event_source_mapping" "firespring_streams" {
  for_each         = var.enable_firespring_sync ? local.firespring_tables : {}
  provider         = aws.us_east_1
  event_source_arn = each.value.stream_arn
  function_name    = aws_lambda_function.firespring_sync[0].arn
  starting_position = "LATEST"
  batch_size       = var.batch_size
  maximum_batching_window_in_seconds = var.batching_window_seconds
  maximum_retry_attempts = var.stream_max_retries
  bisect_batch_on_function_error = true
  parallelization_factor = 1

  filter_criteria {
    filter {
      pattern = jsonencode({
        eventName = ["INSERT", "MODIFY", "REMOVE"]
      })
    }
  }
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "firespring_sync_lambda_arn" {
  description = "ARN of the Firespring sync Lambda function"
  value       = var.enable_firespring_sync ? aws_lambda_function.firespring_sync[0].arn : null
}

output "firespring_tables_configured" {
  description = "List of Firespring tables configured for sync"
  value       = var.enable_firespring_sync ? keys(local.firespring_tables) : []
}
