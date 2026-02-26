// Universal Data Transfer Checksum Validator
// Validates data integrity, detects duplicates, and generates checksums

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: { autoRefreshToken: false, persistSession: false }
})

// Simple hash function for checksums
async function generateChecksum(data: any): Promise<string> {
  const jsonStr = JSON.stringify(data, Object.keys(data).sort())
  const encoder = new TextEncoder()
  const data_bytes = encoder.encode(jsonStr)
  const hashBuffer = await crypto.subtle.digest('SHA-256', data_bytes)
  const hashArray = Array.from(new Uint8Array(hashBuffer))
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('')
}

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    const { action, table, data, source_checksum } = await req.json()

    switch (action) {
      case 'validate':
        return await validateChecksum(table, data, source_checksum)
      case 'check_duplicates':
        return await checkDuplicates(table, data)
      case 'generate':
        return await generateChecksumResponse(data)
      case 'audit':
        return await auditTableIntegrity(table)
      default:
        return new Response(JSON.stringify({ error: 'Unknown action' }), {
          status: 400,
          headers: { 'Content-Type': 'application/json' }
        })
    }
  } catch (error) {
    console.error('Error:', error)
    return new Response(JSON.stringify({
      error: 'Internal server error',
      message: error instanceof Error ? error.message : 'Unknown error'
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})

async function generateChecksumResponse(data: any): Promise<Response> {
  const checksum = await generateChecksum(data)

  return new Response(JSON.stringify({
    checksum: checksum,
    algorithm: 'SHA-256',
    data_size: JSON.stringify(data).length
  }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  })
}

async function validateChecksum(table: string, data: any, sourceChecksum: string): Promise<Response> {
  const computedChecksum = await generateChecksum(data)
  const isValid = computedChecksum === sourceChecksum

  if (!isValid) {
    return new Response(JSON.stringify({
      valid: false,
      source_checksum: sourceChecksum,
      computed_checksum: computedChecksum,
      message: 'Checksum mismatch - data may be corrupted'
    }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' }
    })
  }

  return new Response(JSON.stringify({
    valid: true,
    checksum: computedChecksum,
    message: 'Data integrity verified'
  }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  })
}

async function checkDuplicates(table: string, data: any): Promise<Response> {
  const uniqueField = getUniqueField(table)
  const uniqueValue = data[uniqueField]

  if (!uniqueValue) {
    return new Response(JSON.stringify({
      error: `No unique field value found for ${uniqueField}`
    }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' }
    })
  }

  const { data: existing, error } = await supabase
    .from(table)
    .select('id, created_at, updated_at')
    .eq(uniqueField, uniqueValue)
    .limit(10)

  if (error) {
    throw error
  }

  const isDuplicate = existing && existing.length > 0
  const existingChecksum = isDuplicate ? await generateChecksum(existing[0]) : null
  const newChecksum = await generateChecksum(data)

  return new Response(JSON.stringify({
    is_duplicate: isDuplicate,
    existing_count: existing?.length || 0,
    existing_records: existing,
    data_changed: isDuplicate && existingChecksum !== newChecksum,
    source_checksum: newChecksum,
    existing_checksum: existingChecksum
  }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  })
}

async function auditTableIntegrity(table: string): Promise<Response> {
  const uniqueField = getUniqueField(table)

  // Find duplicates
  const { data: duplicates, error: dupError } = await supabase
    .from(table)
    .select(`${uniqueField}, count:${uniqueField}.count()`)
    .gt('count', 1)

  if (dupError) throw dupError

  // Get total count
  const { count: totalCount, error: countError } = await supabase
    .from(table)
    .select('*', { count: 'exact', head: true })

  if (countError) throw countError

  // Sample records for checksum validation
  const { data: sample, error: sampleError } = await supabase
    .from(table)
    .select('*')
    .limit(100)

  if (sampleError) throw sampleError

  const sampleChecksums = []
  if (sample) {
    for (const record of sample.slice(0, 10)) {
      const checksum = await generateChecksum(record)
      sampleChecksums.push({
        id: record.id,
        checksum: checksum.substring(0, 16)
      })
    }
  }

  return new Response(JSON.stringify({
    table: table,
    total_records: totalCount,
    duplicate_keys: duplicates?.length || 0,
    duplicates: duplicates?.slice(0, 10),
    sample_checksums: sampleChecksums,
    audit_timestamp: new Date().toISOString()
  }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  })
}

function getUniqueField(tableName: string): string {
  const fields: Record<string, string> = {
    'mmp_toledo_leads': 'lead_id',
    'mmp_toledo_otp': 'otp_id',
    'toledo_dashboard': 'pk',
    'firespring_actions': 'action_id',
    'firespring_extraction_jobs': 'job_id',
    'firespring_network_state': 'node_id',
    'firespring_searches': 'search_id',
    'firespring_segments': 'segment_id',
    'firespring_traffic_sources': 'source_id',
    'firespring_visitors': 'visitor_id'
  }
  return fields[tableName] || 'id'
}

console.log('Data Checksum Validator loaded')
