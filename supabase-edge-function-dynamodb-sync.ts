// Supabase Edge Function: DynamoDB to Supabase Sync Webhook
// This function handles incoming webhook requests from AWS/DynamoDB and syncs data to Supabase
// Deploy: supabase functions deploy mmp-toledo-sync --no-verify-jwt
// Project: sbp_973480ddcc0eef6cad5518c1f5fc2beea24b2049

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

// Types for DynamoDB payloads
interface DynamoDBStreamRecord {
  eventID: string
  eventName: 'INSERT' | 'MODIFY' | 'REMOVE'
  eventSource: string
  eventSourceARN: string
  eventVersion: string
  dynamodb?: {
    ApproximateCreationDateTime?: number
    Keys: Record<string, any>
    NewImage?: Record<string, any>
    OldImage?: Record<string, any>
    SequenceNumber: string
    SizeBytes: number
    StreamViewType: string
  }
}

interface DynamoDBWebhookPayload {
  Records: DynamoDBStreamRecord[]
}

interface APIGatewayWebhookPayload {
  httpMethod: string
  path: string
  headers: Record<string, string>
  body: string
  queryStringParameters?: Record<string, string>
}

interface MmpToledoLead {
  lead_id: string
  name?: string
  email?: string
  phone?: string
  company?: string
  message?: string
  source?: string
  campaign_id?: string
  status?: string
  metadata?: Record<string, any>
  dynamodb_pk?: string
  dynamodb_sk?: string
  dynamodb_gsi_data?: Record<string, any>
}

interface MmpToledoOtp {
  otp_id: string
  phone_number: string
  otp_code: string
  status?: string
  attempts?: number
  max_attempts?: number
  expires_at: string
  verified_at?: string
  metadata?: Record<string, any>
  dynamodb_pk?: string
  dynamodb_sk?: string
  ttl?: number
}

interface FirespringRecord {
  id: string
  [key: string]: any
  dynamodb_pk?: string
  dynamodb_sk?: string
}

// Initialize Supabase client
const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
})

// Main handler
Deno.serve(async (req: Request) => {
  console.log(`Function invoked: ${req.method} ${req.url}`)
  
  try {
    // Validate request method
    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({ error: 'Method not allowed' }),
        { 
          status: 405,
          headers: { 'Content-Type': 'application/json' }
        }
      )
    }

    // Parse request body
    const payload = await req.json()
    console.log('Received payload:', JSON.stringify(payload, null, 2))

    // Check if it's a DynamoDB Stream event or API Gateway webhook
    if (payload.Records && Array.isArray(payload.Records)) {
      // Handle DynamoDB Stream records
      return await handleDynamoDBStream(payload as DynamoDBWebhookPayload)
    } else if (payload.body || payload.httpMethod) {
      // Handle API Gateway webhook
      return await handleAPIGatewayWebhook(payload as APIGatewayWebhookPayload)
    } else {
      // Direct webhook payload
      return await handleDirectWebhook(payload)
    }

  } catch (error) {
    console.error('Error processing webhook:', error)
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error',
        message: error instanceof Error ? error.message : 'Unknown error'
      }),
      { 
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      }
    )
  }
})

// Handle DynamoDB Stream records
async function handleDynamoDBStream(payload: DynamoDBWebhookPayload): Promise<Response> {
  const results = []
  
  for (const record of payload.Records) {
    try {
      const result = await processDynamoDBRecord(record)
      results.push(result)
    } catch (error) {
      console.error('Error processing record:', error)
      results.push({ 
        recordId: record.eventID,
        error: error instanceof Error ? error.message : 'Unknown error'
      })
    }
  }

  return new Response(
    JSON.stringify({ 
      message: 'DynamoDB stream processed',
      processed: results.length,
      results 
    }),
    { 
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    }
  )
}

// Handle API Gateway webhook
async function handleAPIGatewayWebhook(payload: APIGatewayWebhookPayload): Promise<Response> {
  const body = typeof payload.body === 'string' ? JSON.parse(payload.body) : payload.body
  
  // Extract table info from headers or path
  const tableName = payload.headers['x-table-name'] || 
                   payload.queryStringParameters?.table ||
                   extractTableFromPath(payload.path)
  
  if (!tableName) {
    return new Response(
      JSON.stringify({ error: 'Table name not specified' }),
      { status: 400, headers: { 'Content-Type': 'application/json' } }
    )
  }

  const result = await syncToSupabaseTable(tableName, body, 'UPSERT')
  
  return new Response(
    JSON.stringify({ 
      message: 'Data synced successfully',
      table: tableName,
      result 
    }),
    { 
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    }
  )
}

// Handle direct webhook (simple JSON payload)
async function handleDirectWebhook(payload: any): Promise<Response> {
  const { table, action = 'UPSERT', data } = payload
  
  if (!table || !data) {
    return new Response(
      JSON.stringify({ error: 'Table and data are required' }),
      { status: 400, headers: { 'Content-Type': 'application/json' } }
    )
  }

  const result = await syncToSupabaseTable(table, data, action)
  
  return new Response(
    JSON.stringify({ 
      message: 'Data synced successfully',
      table,
      action,
      result 
    }),
    { 
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    }
  )
}

// Process individual DynamoDB record
async function processDynamoDBRecord(record: DynamoDBStreamRecord) {
  const { eventName, eventSourceARN, dynamodb } = record
  
  if (!dynamodb) {
    throw new Error('No DynamoDB data in record')
  }

  // Extract table name from ARN
  const tableName = extractTableFromARN(eventSourceARN)
  if (!tableName) {
    throw new Error('Could not extract table name from ARN')
  }

  // Convert DynamoDB image to plain object
  const newData = dynamodb.NewImage ? convertDynamoDBItem(dynamodb.NewImage) : null
  const oldData = dynamodb.OldImage ? convertDynamoDBItem(dynamodb.OldImage) : null

  // Determine action
  let action: string
  switch (eventName) {
    case 'INSERT':
      action = 'INSERT'
      break
    case 'MODIFY':
      action = 'UPDATE'
      break
    case 'REMOVE':
      action = 'DELETE'
      break
    default:
      throw new Error(`Unsupported event name: ${eventName}`)
  }

  // Sync to Supabase
  const result = await syncToSupabaseTable(tableName, newData || oldData, action)
  
  return {
    recordId: record.eventID,
    tableName,
    action,
    success: true,
    result
  }
}

// Convert DynamoDB item format to plain object
function convertDynamoDBItem(item: Record<string, any>): Record<string, any> {
  const result: Record<string, any> = {}
  
  for (const [key, value] of Object.entries(item)) {
    if (typeof value === 'object' && value !== null) {
      if ('S' in value) {
        result[key] = value.S
      } else if ('N' in value) {
        result[key] = parseFloat(value.N)
      } else if ('B' in value) {
        result[key] = value.B
      } else if ('SS' in value) {
        result[key] = value.SS
      } else if ('NS' in value) {
        result[key] = value.NS.map((n: string) => parseFloat(n))
      } else if ('BS' in value) {
        result[key] = value.BS
      } else if ('M' in value) {
        result[key] = convertDynamoDBItem(value.M)
      } else if ('L' in value) {
        result[key] = value.L.map((item: any) => convertDynamoDBItem({ temp: item }).temp)
      } else if ('NULL' in value) {
        result[key] = null
      } else if ('BOOL' in value) {
        result[key] = value.BOOL
      }
    }
  }
  
  return result
}

// Sync data to appropriate Supabase table
async function syncToSupabaseTable(tableName: string, data: any, action: string) {
  const mappedTableName = mapDynamoDBTableToSupabase(tableName)
  const transformedData = transformDataForSupabase(mappedTableName, data)
  
  console.log(`Syncing to table: ${mappedTableName}, action: ${action}`)
  console.log('Transformed data:', JSON.stringify(transformedData, null, 2))

  switch (action) {
    case 'INSERT':
    case 'UPSERT':
      return await upsertToSupabase(mappedTableName, transformedData)
    case 'UPDATE':
      return await updateInSupabase(mappedTableName, transformedData)
    case 'DELETE':
      return await deleteFromSupabase(mappedTableName, transformedData)
    default:
      throw new Error(`Unsupported action: ${action}`)
  }
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
  
  // Add common fields
  if (!transformed.id && !transformed.uuid) {
    // Generate UUID if not present - Supabase will handle this with DEFAULT
  }
  
  // Store original DynamoDB keys for reference
  if (data.id && !transformed.dynamodb_pk) {
    transformed.dynamodb_pk = data.id
  }
  
  // Table-specific transformations
  switch (tableName) {
    case 'mmp_toledo_leads':
      return transformLeadData(transformed)
    case 'mmp_toledo_otp':
      return transformOtpData(transformed)
    default:
      return transformFirespringData(transformed)
  }
}

// Transform MMP Toledo lead data
function transformLeadData(data: any): MmpToledoLead {
  return {
    lead_id: data.lead_id || data.id || `lead_${Date.now()}`,
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
}

// Transform OTP data
function transformOtpData(data: any): MmpToledoOtp {
  return {
    otp_id: data.otp_id || data.id || `otp_${Date.now()}`,
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
}

// Transform Firespring data
function transformFirespringData(data: any): FirespringRecord {
  const result: FirespringRecord = {
    ...data,
    id: data.id || `firespring_${Date.now()}`,
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

// Upsert to Supabase
async function upsertToSupabase(tableName: string, data: any) {
  const { data: result, error } = await supabase
    .from(tableName)
    .upsert(data, { 
      onConflict: getUniqueConstraint(tableName),
      ignoreDuplicates: false 
    })
    .select()
  
  if (error) {
    console.error(`Error upserting to ${tableName}:`, error)
    throw error
  }
  
  return result
}

// Update in Supabase
async function updateInSupabase(tableName: string, data: any) {
  const uniqueField = getUniqueConstraint(tableName)
  const uniqueValue = data[uniqueField]
  
  if (!uniqueValue) {
    throw new Error(`No unique value found for field: ${uniqueField}`)
  }
  
  const { data: result, error } = await supabase
    .from(tableName)
    .update(data)
    .eq(uniqueField, uniqueValue)
    .select()
  
  if (error) {
    console.error(`Error updating in ${tableName}:`, error)
    throw error
  }
  
  return result
}

// Delete from Supabase
async function deleteFromSupabase(tableName: string, data: any) {
  const uniqueField = getUniqueConstraint(tableName)
  const uniqueValue = data[uniqueField]
  
  if (!uniqueValue) {
    throw new Error(`No unique value found for field: ${uniqueField}`)
  }
  
  const { error } = await supabase
    .from(tableName)
    .delete()
    .eq(uniqueField, uniqueValue)
  
  if (error) {
    console.error(`Error deleting from ${tableName}:`, error)
    throw error
  }
  
  return { deleted: true, [uniqueField]: uniqueValue }
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

// Extract table name from DynamoDB ARN
function extractTableFromARN(arn: string): string | null {
  const match = arn.match(/table\/([^\/]+)/)
  return match ? match[1] : null
}

// Extract table name from API Gateway path
function extractTableFromPath(path: string): string | null {
  const match = path.match(/\/sync\/([^\/]+)/)
  return match ? match[1] : null
}

console.log('MMP Toledo DynamoDB Sync function loaded')