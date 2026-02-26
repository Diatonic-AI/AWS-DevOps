// MMP Toledo DynamoDB to Supabase Sync Webhook
// This Edge Function handles incoming webhook requests from AWS/DynamoDB and syncs data to Supabase
// Project ID: jpcdwbkeivtmweoacbsh

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
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
    // MMP Toledo actual tables
    'Lead-sqiqbtbugvfabolqwdt4rz3dla-NONE': 'mmp_toledo_leads',
    'Lead-h6a66mxndnhc7h3o4kldil67oa-NONE': 'mmp_toledo_leads',
    'Lead-sfyatimxznhd3nybi6mcbg5ipq-NONE': 'mmp_toledo_leads',
    'Lead-x5u6a7nejrcfbjj6qld46eamai-NONE': 'mmp_toledo_leads',
    'Lead-xllvnlnajffmznanpuyhq3pl6i-NONE': 'mmp_toledo_leads',
    'toledo-consulting-dashboard-data': 'toledo_dashboard',
    // Legacy names
    'mmp-toledo-leads-prod': 'mmp_toledo_leads',
    'mmp-toledo-otp-prod': 'mmp_toledo_otp',
    'mmp-toledo-leads-otp-prod': 'mmp_toledo_otp',
    // Firespring tables
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
      return transformLeadData(transformed)
    case 'mmp_toledo_otp':
      return transformOtpData(transformed)
    case 'toledo_dashboard':
      return transformDashboardData(transformed)
    case 'firespring_segments':
      return transformFirespringSegments(transformed)
    case 'firespring_actions':
      return transformFirespringActions(transformed)
    case 'firespring_extraction_jobs':
      return transformFirespringJobs(transformed)
    case 'firespring_visitors':
      return transformFirespringVisitors(transformed)
    case 'firespring_traffic_sources':
      return transformFirespringSources(transformed)
    case 'firespring_searches':
      return transformFirespringSearches(transformed)
    case 'firespring_network_state':
      return transformFirespringNetworkState(transformed)
    default:
      return transformFirespringGeneric(transformed)
  }
}

// Transform MMP Toledo lead data
function transformLeadData(data: any) {
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
function transformOtpData(data: any) {
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

// Transform Toledo Dashboard data - matches actual table schema
function transformDashboardData(data: any) {
  // Extract pk and sk from DynamoDB format
  const pk = data.pk || data.PK || data.id || `dashboard_${Date.now()}`
  const sk = data.sk || data.SK || 'default'

  // Build metrics object from all other data
  const { pk: _, sk: __, PK: ___, SK: ____, id: _____, dynamodb_pk: ______, dynamodb_sk: _______, ...rest } = data

  return {
    pk: pk,
    sk: sk,
    metrics: rest,  // Store all other fields as metrics JSON
    last_updated: new Date().toISOString(),
    dynamodb_pk: data.pk || data.PK || data.id,
    dynamodb_sk: data.sk || data.SK
  }
}

// Transform Firespring segments - map DynamoDB fields to Supabase schema
function transformFirespringSegments(data: any) {
  // Remove import metadata fields that don't exist in schema
  const { _source_table, _import_timestamp, ...cleanData } = data

  return {
    segment_id: cleanData.segment_id || `segment_${Date.now()}`,
    segment_name: cleanData.name || cleanData.segment_name,
    segment_criteria: cleanData.raw || cleanData.segment_criteria || {},
    member_count: cleanData.value !== undefined ? cleanData.value : (cleanData.member_count || 0),
    dynamodb_pk: cleanData.segment_id,
    dynamodb_sk: cleanData.timestamp ? String(cleanData.timestamp) : null,
    created_at: cleanData.created_at ? new Date(Number(cleanData.created_at)).toISOString() : undefined,
    updated_at: cleanData.timestamp ? new Date(Number(cleanData.timestamp)).toISOString() : undefined
  }
}

// Transform Firespring actions
function transformFirespringActions(data: any) {
  const { _source_table, _import_timestamp, ...cleanData } = data

  return {
    action_id: cleanData.action_id || cleanData.id || `action_${Date.now()}`,
    action_type: cleanData.action_type || cleanData.type,
    action_data: cleanData.data || cleanData.action_data || {},
    status: cleanData.status,
    dynamodb_pk: cleanData.action_id || cleanData.id,
    dynamodb_sk: cleanData.timestamp || cleanData.sk,
    created_at: cleanData.created_at ? new Date(Number(cleanData.created_at)).toISOString() : undefined
  }
}

// Transform Firespring extraction jobs
function transformFirespringJobs(data: any) {
  const { _source_table, _import_timestamp, ...cleanData } = data

  return {
    job_id: cleanData.job_id || cleanData.id || `job_${Date.now()}`,
    job_type: cleanData.job_type || cleanData.type,
    status: cleanData.status,
    progress: cleanData.progress || {},
    results: cleanData.results || {},
    error_message: cleanData.error || cleanData.error_message,
    dynamodb_pk: cleanData.job_id || cleanData.id,
    dynamodb_sk: cleanData.timestamp || cleanData.sk,
    created_at: cleanData.created_at ? new Date(Number(cleanData.created_at)).toISOString() : undefined
  }
}

// Transform Firespring visitors - combine multiple fields into session_data
function transformFirespringVisitors(data: any) {
  const { _source_table, _import_timestamp, ...cleanData } = data

  // Extract key fields
  const sessionId = cleanData.session_id || cleanData.visitor_id || cleanData.id
  const pagesViewed = cleanData.pages_viewed || cleanData.page_views || cleanData.pages || 0
  const timestamp = cleanData.timestamp || cleanData.created_at
  const createdAt = cleanData.created_at || cleanData.timestamp

  // Combine all visitor metadata into session_data jsonb
  const sessionData = {
    ip_address: cleanData.ip_address,
    user_agent: cleanData.user_agent,
    country: cleanData.country,
    city: cleanData.city,
    referrer: cleanData.referrer,
    landing_page: cleanData.landing_page,
    exit_page: cleanData.exit_page,
    organization: cleanData.organization,
    is_bounce: cleanData.is_bounce,
    duration: cleanData.duration,
    pages_viewed: pagesViewed,
    custom_data: cleanData.custom_data || {},
    raw: cleanData.raw || {}
  }

  return {
    visitor_id: sessionId || `visitor_${Date.now()}`,
    session_data: sessionData,
    page_views: pagesViewed,
    last_visit_at: timestamp ? new Date(Number(timestamp)).toISOString() : null,
    dynamodb_pk: sessionId,
    dynamodb_sk: timestamp ? String(timestamp) : null,
    created_at: createdAt ? new Date(Number(createdAt)).toISOString() : undefined
  }
}

// Transform Firespring traffic sources
function transformFirespringSources(data: any) {
  const { _source_table, _import_timestamp, ...cleanData } = data

  return {
    source_id: cleanData.source_id || cleanData.id || `source_${Date.now()}`,
    source_name: cleanData.name || cleanData.source_name,
    source_type: cleanData.type || cleanData.source_type,
    traffic_data: cleanData.data || cleanData.traffic_data || {},
    dynamodb_pk: cleanData.source_id || cleanData.id,
    dynamodb_sk: cleanData.timestamp || cleanData.sk,
    created_at: cleanData.created_at ? new Date(Number(cleanData.created_at)).toISOString() : undefined
  }
}

// Transform Firespring searches
function transformFirespringSearches(data: any) {
  const { _source_table, _import_timestamp, search_metadata, ...cleanData } = data

  return {
    search_id: cleanData.search_id || `search_${Date.now()}`,
    search_query: cleanData.search_query || cleanData.query || cleanData.term,
    search_type: cleanData.search_type || 'organic',
    results_count: cleanData.results_count || 0,
    search_metadata: search_metadata || cleanData.metadata || {},
    dynamodb_pk: cleanData.search_id,
    dynamodb_sk: cleanData.timestamp ? String(cleanData.timestamp) : null,
    created_at: cleanData.created_at ? new Date(Number(cleanData.created_at)).toISOString() : undefined
  }
}

// Transform Firespring network state - NAT Gateway lifecycle tracking
function transformFirespringNetworkState(data: any) {
  const { _source_table, _import_timestamp, resource_id, ...cleanData } = data

  return {
    node_id: cleanData.nat_gateway_id || cleanData.node_id || `node_${Date.now()}`,
    node_type: 'nat_gateway',

    // NAT Gateway details
    nat_gateway_id: cleanData.nat_gateway_id,
    vpc_id: cleanData.vpc_id,
    subnet_id: cleanData.subnet_id,
    state: cleanData.status || cleanData.state,

    // Activity tracking
    last_activity_timestamp: cleanData.discovered_at ?
      new Date(Number(cleanData.discovered_at)).toISOString() : null,
    idle_duration_seconds: cleanData.idle_duration_seconds,

    // Lifecycle
    stopped_at: cleanData.stopped_at ? new Date(cleanData.stopped_at).toISOString() : null,
    started_at: cleanData.created_at ? new Date(Number(cleanData.created_at)).toISOString() : null,
    cost_savings_usd: cleanData.cost_savings_usd || 0,

    // State data (all other fields)
    state_data: {
      allocation_id: cleanData.allocation_id,
      discovered_at: cleanData.discovered_at,
      updated_at: cleanData.updated_at,
      ...cleanData
    },

    last_seen_at: new Date().toISOString(),
    dynamodb_pk: resource_id || cleanData.nat_gateway_id,
    dynamodb_sk: cleanData.updated_at ? String(cleanData.updated_at) : null
  }
}

// Generic Firespring transformation (fallback)
function transformFirespringGeneric(data: any) {
  const { _source_table, _import_timestamp, ...cleanData } = data

  const result = {
    ...cleanData,
    dynamodb_pk: cleanData.dynamodb_pk || cleanData.id,
    dynamodb_sk: cleanData.dynamodb_sk || cleanData.timestamp
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
    'toledo_dashboard': 'pk,sk',  // Composite unique key
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
