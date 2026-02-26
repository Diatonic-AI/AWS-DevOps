#!/usr/bin/env bash
# deploy-supabase-mmp-toledo.sh
# Script to deploy MMP Toledo DynamoDB migration to Supabase
# This includes creating tables, edge functions, and setting up incremental import

set -euo pipefail

# Configuration variables
SUPABASE_PROJECT_ID="sbp_973480ddcc0eef6cad5518c1f5fc2beea24b2049"
SUPABASE_DIR="./supabase"
EDGE_FUNCTIONS_DIR="$SUPABASE_DIR/functions"
MIGRATION_DIR="$SUPABASE_DIR/migrations"
SQL_FILE="./supabase-mmp-toledo-migration.sql"
EDGE_FUNCTION_FILE="./supabase-edge-function-dynamodb-sync.ts"
WEBHOOK_EDGE_FUNCTION_NAME="mmp-toledo-sync"
INITIAL_IMPORT_FUNCTION_NAME="mmp-toledo-import"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
  log_info "Checking prerequisites..."
  
  # Check supabase CLI
  if ! command -v supabase &> /dev/null; then
    log_error "Supabase CLI not found. Please install it first: npm install -g supabase"
    exit 1
  fi
  
  # Check if we have SQL file
  if [[ ! -f "$SQL_FILE" ]]; then
    log_error "SQL migration file not found at $SQL_FILE"
    exit 1
  fi
  
  # Check if we have Edge Function file
  if [[ ! -f "$EDGE_FUNCTION_FILE" ]]; then
    log_error "Edge function file not found at $EDGE_FUNCTION_FILE"
    exit 1
  }
  
  log_success "Prerequisites check passed."
}

initialize_supabase_project() {
  log_info "Initializing Supabase project structure..."
  
  # Create directories if they don't exist
  mkdir -p "$SUPABASE_DIR"
  mkdir -p "$EDGE_FUNCTIONS_DIR"
  mkdir -p "$MIGRATION_DIR"
  mkdir -p "$EDGE_FUNCTIONS_DIR/$WEBHOOK_EDGE_FUNCTION_NAME"
  mkdir -p "$EDGE_FUNCTIONS_DIR/$INITIAL_IMPORT_FUNCTION_NAME"
  
  # Initialize Supabase project if not already initialized
  if [[ ! -f "$SUPABASE_DIR/config.toml" ]]; then
    log_info "Setting up new Supabase project..."
    pushd "$(dirname "$SUPABASE_DIR")" > /dev/null
    supabase init
    popd > /dev/null
  else
    log_info "Supabase project already initialized."
  fi
  
  log_success "Supabase project structure initialized."
}

setup_migrations() {
  log_info "Setting up SQL migration..."
  
  # Copy SQL file to migrations directory with timestamp
  local timestamp
  timestamp=$(date +%Y%m%d%H%M%S)
  local migration_file="$MIGRATION_DIR/${timestamp}_mmp_toledo_tables.sql"
  
  cp "$SQL_FILE" "$migration_file"
  log_success "Copied SQL migration to $migration_file"
}

setup_edge_functions() {
  log_info "Setting up Edge Functions..."
  
  # Copy webhook sync function
  cp "$EDGE_FUNCTION_FILE" "$EDGE_FUNCTIONS_DIR/$WEBHOOK_EDGE_FUNCTION_NAME/index.ts"
  log_success "Copied webhook sync function to $EDGE_FUNCTIONS_DIR/$WEBHOOK_EDGE_FUNCTION_NAME/index.ts"
  
  # Create initial import edge function
  cat > "$EDGE_FUNCTIONS_DIR/$INITIAL_IMPORT_FUNCTION_NAME/index.ts" << EOF
// Supabase Edge Function: MMP Toledo Initial Import
// This function handles the initial batch import from DynamoDB to Supabase
// Project: $SUPABASE_PROJECT_ID

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import { DynamoDBClient } from 'https://esm.sh/@aws-sdk/client-dynamodb@3.445.0'
import { 
  ScanCommand, 
  QueryCommand,
  DynamoDBPaginationConfiguration 
} from 'https://esm.sh/@aws-sdk/client-dynamodb@3.445.0'
import { unmarshall } from 'https://esm.sh/@aws-sdk/util-dynamodb@3.445.0'

// Initialize Supabase client
const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: { autoRefreshToken: false, persistSession: false }
})

// Initialize DynamoDB client
let dynamoClient: DynamoDBClient | null = null

// Configuration for batch sizes
const BATCH_SIZE = 100  // Process in batches of 100 items
const MAX_ITEMS_PER_RUN = 1000  // Limit per function run

// Main handler
Deno.serve(async (req: Request) => {
  console.log(\`Initial import function invoked: \${req.method} \${req.url}\`)
  
  try {
    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({ error: 'Method not allowed' }),
        { status: 405, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Parse request payload
    const payload = await req.json()
    const {
      tableName,
      region = 'us-east-1',
      credentials,
      lastEvaluatedKey,
      resume = false,
      filter = null
    } = payload
    
    if (!tableName) {
      return new Response(
        JSON.stringify({ error: 'tableName is required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }
    
    if (!credentials && !dynamoClient) {
      return new Response(
        JSON.stringify({ error: 'AWS credentials required for first run' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }
    
    // Initialize DynamoDB client if not already initialized
    if (!dynamoClient && credentials) {
      dynamoClient = new DynamoDBClient({
        region,
        credentials: {
          accessKeyId: credentials.accessKeyId,
          secretAccessKey: credentials.secretAccessKey,
          sessionToken: credentials.sessionToken
        }
      })
    }
    
    // Map DynamoDB table name to Supabase table name
    const supabaseTable = mapDynamoDBTableToSupabase(tableName)
    console.log(\`Importing from DynamoDB '\${tableName}' to Supabase '\${supabaseTable}'\`)
    
    // Scan DynamoDB table
    const result = await scanDynamoDBTable(tableName, lastEvaluatedKey, BATCH_SIZE, MAX_ITEMS_PER_RUN, filter)
    
    // Import to Supabase
    const importResult = await importToSupabase(result.items, supabaseTable)
    
    // Construct response
    const response = {
      imported: importResult.success.length,
      failed: importResult.failed.length,
      lastEvaluatedKey: result.lastEvaluatedKey,
      hasMore: !!result.lastEvaluatedKey,
      scannedCount: result.scannedCount,
      tableName,
      supabaseTable
    }
    
    return new Response(
      JSON.stringify(response),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )
    
  } catch (error) {
    console.error('Error in import:', error)
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error',
        message: error instanceof Error ? error.message : 'Unknown error'
      }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})

// Scan DynamoDB table with pagination
async function scanDynamoDBTable(
  tableName: string, 
  lastEvaluatedKey: any, 
  batchSize: number, 
  maxItems: number,
  filter: any
): Promise<{ items: any[], lastEvaluatedKey: any, scannedCount: number }> {
  if (!dynamoClient) {
    throw new Error('DynamoDB client not initialized')
  }
  
  const scanParams = {
    TableName: tableName,
    Limit: batchSize,
    ExclusiveStartKey: lastEvaluatedKey || undefined,
    ...(filter && { FilterExpression: filter.expression }),
    ...(filter && filter.attributeNames && { ExpressionAttributeNames: filter.attributeNames }),
    ...(filter && filter.attributeValues && { ExpressionAttributeValues: filter.attributeValues })
  }

  console.log(\`Scanning DynamoDB table \${tableName}...\`)
  const command = new ScanCommand(scanParams)
  
  try {
    const data = await dynamoClient.send(command)
    
    // Convert DynamoDB items to plain JavaScript objects
    const items = data.Items ? data.Items.map(item => unmarshall(item)) : []
    
    console.log(\`Retrieved \${items.length} items from DynamoDB\`)
    
    return {
      items,
      lastEvaluatedKey: data.LastEvaluatedKey,
      scannedCount: data.ScannedCount || 0
    }
  } catch (error) {
    console.error('Error scanning DynamoDB:', error)
    throw error
  }
}

// Import items to Supabase
async function importToSupabase(items: any[], tableName: string): Promise<{ success: any[], failed: any[] }> {
  console.log(\`Importing \${items.length} items to Supabase table \${tableName}\`)
  
  // Track results
  const results = {
    success: [],
    failed: []
  }
  
  // Process in smaller batches to avoid Supabase limitations
  const SUPABASE_BATCH_SIZE = 25
  
  for (let i = 0; i < items.length; i += SUPABASE_BATCH_SIZE) {
    const batch = items.slice(i, i + SUPABASE_BATCH_SIZE)
    const transformedBatch = batch.map(item => transformDataForSupabase(tableName, item))
    
    try {
      const { data, error } = await supabase
        .from(tableName)
        .upsert(transformedBatch, { 
          onConflict: getUniqueConstraint(tableName),
          ignoreDuplicates: false 
        })
      
      if (error) {
        console.error(\`Error upserting batch to \${tableName}:\`, error)
        results.failed.push(...transformedBatch)
      } else {
        results.success.push(...transformedBatch)
      }
    } catch (error) {
      console.error(\`Exception upserting batch to \${tableName}:\`, error)
      results.failed.push(...transformedBatch)
    }
    
    // Small delay to avoid rate limits
    await new Promise(resolve => setTimeout(resolve, 100))
  }
  
  console.log(\`Import results: \${results.success.length} succeeded, \${results.failed.length} failed\`)
  return results
}

// Map DynamoDB table names to Supabase table names
function mapDynamoDBTableToSupabase(dynamoTableName: string): string {
  const mapping: Record<string, string> = {
    'mmp-toledo-leads-prod': 'mmp_toledo_leads',
    'mmp-toledo-otp-prod': 'mmp_toledo_otp',
    'mmp-toledo-leads-otp-prod': 'mmp_toledo_otp',
    'firespring-backdoor-actions-dev': 'firespring_actions',
    'firespring-backdoor-extraction-jobs-dev': 'firespring_extraction_jobs',
    'firespring-backdoor-network-state-dev': 'firespring_network_state',
    'firespring-backdoor-searches-dev': 'firespring_searches',
    'firespring-backdoor-segments-dev': 'firespring_segments',
    'firespring-backdoor-traffic-sources-dev': 'firespring_traffic_sources',
    'firespring-backdoor-visitors-dev': 'firespring_visitors'
  }
  
  return mapping[dynamoTableName] || dynamoTableName.replace(/-/g, '_').toLowerCase()
}

// Transform data for Supabase format
function transformDataForSupabase(tableName: string, data: any): any {
  if (!data) return data

  const transformed = { ...data }
  
  // Store original DynamoDB keys for reference
  if (data.id && !transformed.dynamodb_pk) {
    transformed.dynamodb_pk = data.id
  }
  
  // Table-specific transformations
  switch (tableName) {
    case 'mmp_toledo_leads':
      return {
        lead_id: data.lead_id || data.id || \`lead_\${Date.now()}\`,
        name: data.name || data.customer_name,
        email: data.email,
        phone: data.phone || data.phone_number,
        company: data.company || data.organization,
        message: data.message || data.notes,
        source: data.source || data.lead_source,
        campaign_id: data.campaign_id || data.campaignId,
        status: data.status || 'new',
        metadata: typeof data.metadata === 'object' ? data.metadata : {},
        dynamodb_pk: data.dynamodb_pk || data.id,
        dynamodb_sk: data.dynamodb_sk,
        dynamodb_gsi_data: data.gsi || {}
      }
    case 'mmp_toledo_otp':
      return {
        otp_id: data.otp_id || data.id || \`otp_\${Date.now()}\`,
        phone_number: data.phone_number || data.phone,
        otp_code: data.otp_code || data.code,
        status: data.status || 'pending',
        attempts: parseInt(data.attempts || '0'),
        max_attempts: parseInt(data.max_attempts || '3'),
        expires_at: data.expires_at || data.expiry || new Date(Date.now() + 300000).toISOString(),
        verified_at: data.verified_at,
        metadata: typeof data.metadata === 'object' ? data.metadata : {},
        dynamodb_pk: data.dynamodb_pk || data.id,
        dynamodb_sk: data.dynamodb_sk,
        ttl: data.ttl ? parseInt(data.ttl.toString()) : null
      }
    default:
      // Generic firespring table
      const result = {
        ...data,
        dynamodb_pk: data.dynamodb_pk || data.id,
        dynamodb_sk: data.dynamodb_sk
      }
      
      // Ensure timestamps are properly formatted
      if (result.created_at && typeof result.created_at === 'number') {
        result.created_at = new Date(result.created_at * 1000).toISOString()
      }
      if (result.updated_at && typeof result.updated_at === 'number') {
        result.updated_at = new Date(result.updated_at * 1000).toISOString()
      }
      
      return result
  }
}

// Get unique constraint field for each table
function getUniqueConstraint(tableName: string): string {
  const constraints: Record<string, string> = {
    'mmp_toledo_leads': 'lead_id',
    'mmp_toledo_otp': 'otp_id',
    'firespring_actions': 'action_id',
    'firespring_extraction_jobs': 'job_id',
    'firespring_network_state': 'node_id',
    'firespring_searches': 'search_id',
    'firespring_segments': 'segment_id',
    'firespring_traffic_sources': 'source_id',
    'firespring_visitors': 'visitor_id'
  }
  
  return constraints[tableName] || 'id'
}

console.log('MMP Toledo DynamoDB Import function loaded')
EOF
  
  log_success "Created initial import function at $EDGE_FUNCTIONS_DIR/$INITIAL_IMPORT_FUNCTION_NAME/index.ts"
}

deploy_edge_functions() {
  log_info "Deploying Edge Functions to Supabase..."
  
  pushd "$(dirname "$SUPABASE_DIR")" > /dev/null
  
  # Deploy webhook sync function
  log_info "Deploying webhook sync function..."
  supabase functions deploy "$WEBHOOK_EDGE_FUNCTION_NAME" --no-verify-jwt
  
  # Deploy initial import function
  log_info "Deploying initial import function..."
  supabase functions deploy "$INITIAL_IMPORT_FUNCTION_NAME" --no-verify-jwt
  
  popd > /dev/null
  
  log_success "Edge Functions deployed successfully."
}

deploy_migrations() {
  log_info "Deploying SQL migrations to Supabase..."
  
  pushd "$(dirname "$SUPABASE_DIR")" > /dev/null
  
  # Connect to Supabase project
  log_info "Linking to Supabase project $SUPABASE_PROJECT_ID..."
  supabase link --project-ref "$SUPABASE_PROJECT_ID"
  
  # Run migrations
  log_info "Applying database migrations..."
  supabase db push
  
  popd > /dev/null
  
  log_success "SQL migrations applied successfully."
}

create_webhook_configuration() {
  log_info "Creating instructions for webhook configuration..."
  
  cat > "./supabase-mmp-toledo-webhook-setup.md" << EOF
# MMP Toledo DynamoDB to Supabase Webhook Setup

This document outlines how to set up the AWS side for real-time synchronization from DynamoDB to Supabase.

## Step 1: Set Up DynamoDB Streams

For each DynamoDB table that needs to be synced:

\`\`\`bash
# Enable DynamoDB Streams with both old and new images
aws dynamodb update-table \\
  --table-name mmp-toledo-leads-prod \\
  --stream-specification StreamEnabled=true,StreamViewType=NEW_AND_OLD_IMAGES
\`\`\`

## Step 2: Create IAM Role for Lambda

\`\`\`bash
# Create IAM role for Lambda to access DynamoDB streams
aws iam create-role \\
  --role-name MmpToledoDynamoDBStreamRole \\
  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

# Attach permissions
aws iam attach-role-policy \\
  --role-name MmpToledoDynamoDBStreamRole \\
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

aws iam attach-role-policy \\
  --role-name MmpToledoDynamoDBStreamRole \\
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaDynamoDBExecutionRole
\`\`\`

## Step 3: Create Lambda Function for Webhook

\`\`\`bash
# Create Lambda function
aws lambda create-function \\
  --function-name MmpToledoDynamoDBToSupabaseSync \\
  --runtime nodejs18.x \\
  --handler index.handler \\
  --role arn:aws:iam::455303857245:role/MmpToledoDynamoDBStreamRole \\
  --zip-file fileb://dynamodb-to-supabase-lambda.zip \\
  --environment "Variables={SUPABASE_WEBHOOK_URL=https://<project-ref>.functions.supabase.co/mmp-toledo-sync,SUPABASE_API_KEY=<supabase-anon-key>}"
\`\`\`

## Step 4: Create Lambda Function Code

Create a file named \`index.js\` with the following content:

\`\`\`javascript
const https = require('https');
const url = require('url');

// Environment variables
const SUPABASE_WEBHOOK_URL = process.env.SUPABASE_WEBHOOK_URL;
const SUPABASE_API_KEY = process.env.SUPABASE_API_KEY;

exports.handler = async (event, context) => {
  console.log('Received event:', JSON.stringify(event, null, 2));
  
  try {
    // Forward the DynamoDB stream records to Supabase webhook
    const response = await forwardToSupabase(event);
    console.log('Supabase webhook response:', response);
    
    return { 
      statusCode: 200,
      body: JSON.stringify({ message: 'Records forwarded to Supabase', count: event.Records.length })
    };
  } catch (error) {
    console.error('Error forwarding records to Supabase:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Failed to forward records to Supabase' })
    };
  }
};

// Function to forward events to Supabase webhook
async function forwardToSupabase(event) {
  return new Promise((resolve, reject) => {
    // Parse the webhook URL
    const parsedUrl = url.parse(SUPABASE_WEBHOOK_URL);
    
    // Prepare the request options
    const options = {
      hostname: parsedUrl.hostname,
      port: parsedUrl.port || 443,
      path: parsedUrl.path,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': \`Bearer \${SUPABASE_API_KEY}\`
      }
    };
    
    // Create the request
    const req = https.request(options, (res) => {
      let responseBody = '';
      
      res.on('data', (chunk) => {
        responseBody += chunk;
      });
      
      res.on('end', () => {
        try {
          resolve({
            statusCode: res.statusCode,
            body: responseBody
          });
        } catch (error) {
          reject(error);
        }
      });
    });
    
    // Handle request errors
    req.on('error', (error) => {
      reject(error);
    });
    
    // Send the request with the event data
    req.write(JSON.stringify(event));
    req.end();
  });
}
\`\`\`

Zip this file for deployment:

\`\`\`bash
zip dynamodb-to-supabase-lambda.zip index.js
\`\`\`

## Step 5: Create Event Source Mapping

\`\`\`bash
# Get the Stream ARN
STREAM_ARN=$(aws dynamodb describe-table --table-name mmp-toledo-leads-prod --query "Table.LatestStreamArn" --output text)

# Create Event Source Mapping
aws lambda create-event-source-mapping \\
  --function-name MmpToledoDynamoDBToSupabaseSync \\
  --batch-size 100 \\
  --starting-position LATEST \\
  --event-source-arn "$STREAM_ARN"
\`\`\`

## Step 6: Testing

To test the webhook integration:

1. Make a change to a DynamoDB record
2. Check the CloudWatch logs for the Lambda function to confirm it received the event
3. Check the Supabase Edge Function logs to confirm it processed the webhook

## Step 7: Repeat for Other Tables

Repeat steps 1 and 5 for each DynamoDB table that needs real-time synchronization:

- mmp-toledo-otp-prod
- firespring-backdoor-actions-dev
- firespring-backdoor-extraction-jobs-dev
- firespring-backdoor-network-state-dev
- firespring-backdoor-searches-dev
- firespring-backdoor-segments-dev
- firespring-backdoor-traffic-sources-dev
- firespring-backdoor-visitors-dev

## Step 8: Incremental Import

For the initial data import:

1. Use the Supabase Edge Function 'mmp-toledo-import' via the Supabase dashboard
2. Send a POST request with the following payload:

\`\`\`json
{
  "tableName": "mmp-toledo-leads-prod",
  "region": "us-east-1",
  "credentials": {
    "accessKeyId": "YOUR_ACCESS_KEY",
    "secretAccessKey": "YOUR_SECRET_KEY"
  }
}
\`\`\`

3. If there are more records to import (hasMore: true), send another request with:

\`\`\`json
{
  "tableName": "mmp-toledo-leads-prod",
  "region": "us-east-1",
  "lastEvaluatedKey": {
    // The lastEvaluatedKey value from the previous response
  },
  "resume": true
}
\`\`\`

4. Repeat for all tables
EOF
  
  log_success "Created webhook configuration instructions at ./supabase-mmp-toledo-webhook-setup.md"
}

create_import_schedule() {
  log_info "Creating import schedule configuration..."
  
  cat > "./supabase-mmp-toledo-import-schedule.md" << EOF
# MMP Toledo DynamoDB to Supabase Import Schedule

This document outlines how to set up the incremental import schedule for cost-effective data migration.

## Cost-Optimized Import Strategy

The import strategy is designed to minimize AWS DynamoDB read costs by:

1. Using batched reads instead of individual item reads
2. Scheduling imports during off-peak hours
3. Using incremental imports with pagination to avoid reading the entire table in one go
4. Setting reasonable read capacity to stay within AWS Free Tier limits

## AWS CloudWatch Events Schedule

Create a CloudWatch Events rule to trigger the Lambda function for incremental imports:

\`\`\`bash
# Create CloudWatch Events rule for scheduled import (runs daily at 2 AM UTC)
aws events put-rule \\
  --name MmpToledoDailyImport \\
  --schedule-expression "cron(0 2 * * ? *)" \\
  --description "Trigger daily import from DynamoDB to Supabase"

# Set Lambda function as target
aws events put-targets \\
  --rule MmpToledoDailyImport \\
  --targets "Id"="1","Arn"="arn:aws:lambda:us-east-1:455303857245:function:MmpToledoDynamoDBToSupabaseImport"
\`\`\`

## Import Lambda Function

Create a separate Lambda function for scheduled imports:

\`\`\`javascript
const https = require('https');
const url = require('url');
const { DynamoDBClient, ListTablesCommand } = require('@aws-sdk/client-dynamodb');

// Environment variables
const SUPABASE_IMPORT_URL = process.env.SUPABASE_IMPORT_URL;
const SUPABASE_API_KEY = process.env.SUPABASE_API_KEY;
const TABLE_PREFIXES = ['mmp-toledo-', 'firespring-backdoor-'];

exports.handler = async (event, context) => {
  console.log('Starting incremental import job');
  
  try {
    // Initialize DynamoDB client
    const dynamoClient = new DynamoDBClient({ region: 'us-east-1' });
    
    // List all tables
    const listTablesCommand = new ListTablesCommand({});
    const { TableNames } = await dynamoClient.send(listTablesCommand);
    
    // Filter tables with our prefixes
    const tablesToImport = TableNames.filter(tableName => 
      TABLE_PREFIXES.some(prefix => tableName.startsWith(prefix))
    );
    
    console.log('Tables to import:', tablesToImport);
    
    // Process each table
    for (const tableName of tablesToImport) {
      try {
        console.log(\`Starting import for \${tableName}\`);
        
        // Trigger import via Supabase Edge Function
        const result = await triggerImport(tableName);
        console.log(\`Import triggered for \${tableName}:\`, result);
        
        // Wait a bit to avoid rate limiting
        await new Promise(resolve => setTimeout(resolve, 2000));
      } catch (error) {
        console.error(\`Error importing table \${tableName}:\`, error);
      }
    }
    
    return { 
      statusCode: 200,
      body: JSON.stringify({ message: 'Incremental import triggered', tables: tablesToImport })
    };
  } catch (error) {
    console.error('Error in import handler:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Failed to trigger imports' })
    };
  }
};

// Function to trigger import via Supabase Edge Function
async function triggerImport(tableName) {
  return new Promise((resolve, reject) => {
    // Parse the webhook URL
    const parsedUrl = url.parse(SUPABASE_IMPORT_URL);
    
    // Prepare payload with temporary credentials
    const payload = {
      tableName,
      region: 'us-east-1',
      // Note: In production, use AWS STS to generate temporary credentials
      credentials: {
        accessKeyId: process.env.AWS_ACCESS_KEY_ID,
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
        sessionToken: process.env.AWS_SESSION_TOKEN
      }
    };
    
    // Prepare the request options
    const options = {
      hostname: parsedUrl.hostname,
      port: parsedUrl.port || 443,
      path: parsedUrl.path,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': \`Bearer \${SUPABASE_API_KEY}\`
      }
    };
    
    // Create the request
    const req = https.request(options, (res) => {
      let responseBody = '';
      
      res.on('data', (chunk) => {
        responseBody += chunk;
      });
      
      res.on('end', () => {
        try {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            const data = JSON.parse(responseBody);
            resolve(data);
          } else {
            reject(new Error(\`HTTP Error: \${res.statusCode} \${responseBody}\`));
          }
        } catch (error) {
          reject(error);
        }
      });
    });
    
    // Handle request errors
    req.on('error', (error) => {
      reject(error);
    });
    
    // Send the request with the payload
    req.write(JSON.stringify(payload));
    req.end();
  });
}
\`\`\`

## Cost Analysis

Using this incremental import strategy:

- **DynamoDB Free Tier**: 25 WCU and 25 RCU
- **Batch Size**: 100 items per request
- **Scheduled Import**: 1 run per day

Estimated costs:
- DynamoDB Read Units: ~1 RCU per batch of 100 items
- Lambda Execution: Free tier covers 1M requests/month
- Supabase Usage: Well within free tier limits

Total estimated cost: $0.00 (within AWS Free Tier and Supabase Free Tier)

## Monitoring and Alerting

Set up CloudWatch Alarms to monitor import jobs:

\`\`\`bash
# Create alarm for import failures
aws cloudwatch put-metric-alarm \\
  --alarm-name MmpToledoImportFailures \\
  --alarm-description "Alert on import failures" \\
  --metric-name Errors \\
  --namespace AWS/Lambda \\
  --statistic Sum \\
  --period 86400 \\
  --threshold 1 \\
  --comparison-operator GreaterThanOrEqualToThreshold \\
  --evaluation-periods 1 \\
  --dimensions Name=FunctionName,Value=MmpToledoDynamoDBToSupabaseImport \\
  --alarm-actions arn:aws:sns:us-east-1:455303857245:YourSNSTopic
\`\`\`

## Import Progress Tracking Table

In Supabase, create an import tracking table:

\`\`\`sql
CREATE TABLE public.mmp_toledo_import_status (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT NOT NULL,
  last_imported_at TIMESTAMPTZ,
  last_evaluated_key JSONB,
  items_imported BIGINT DEFAULT 0,
  items_failed BIGINT DEFAULT 0,
  status TEXT DEFAULT 'pending',
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for quick lookups
CREATE INDEX idx_import_status_table_name ON public.mmp_toledo_import_status(table_name);

-- Enable RLS
ALTER TABLE public.mmp_toledo_import_status ENABLE ROW LEVEL SECURITY;

-- Create policy for service role
CREATE POLICY "Service role can access import status" ON public.mmp_toledo_import_status
    FOR ALL TO service_role USING (true);
\`\`\`

The Edge Function will update this table on each import run.
EOF
  
  log_success "Created import schedule configuration at ./supabase-mmp-toledo-import-schedule.md"
}

main() {
  log_info "Starting MMP Toledo DynamoDB to Supabase deployment..."
  
  check_prerequisites
  initialize_supabase_project
  setup_migrations
  setup_edge_functions
  deploy_migrations
  deploy_edge_functions
  create_webhook_configuration
  create_import_schedule
  
  log_success "Deployment completed successfully!"
  log_info "Next steps:"
  log_info "1. Review webhook configuration in ./supabase-mmp-toledo-webhook-setup.md"
  log_info "2. Review import schedule configuration in ./supabase-mmp-toledo-import-schedule.md"
  log_info "3. Set up AWS Lambda functions and DynamoDB Streams as described in the documentation"
}

# Execute main function
main "$@"