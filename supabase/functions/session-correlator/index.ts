// Session Correlator - Canonical User & Session Tracking
// Transforms Firespring visitor data into unified canonical sessions
// Enables cross-platform user journey tracking and attribution

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  { auth: { autoRefreshToken: false, persistSession: false } }
)

// Generate canonical user ID from device fingerprint
function generateCanonicalUserId(visitorData: any): string {
  // Use IP + browser + OS as fingerprint (more sophisticated in production)
  const fingerprint = [
    visitorData.ip_address || 'unknown',
    visitorData.browser || 'unknown',
    visitorData.os || 'unknown',
    visitorData.organization || 'unknown'
  ].join('|')

  // Simple hash for demo (use crypto.subtle.digest in production)
  let hash = 0
  for (let i = 0; i < fingerprint.length; i++) {
    hash = ((hash << 5) - hash) + fingerprint.charCodeAt(i)
    hash = hash & hash
  }

  return `user_${Math.abs(hash).toString(36)}`
}

Deno.serve(async (req: Request) => {
  try {
    const { action, data } = await req.json()

    switch (action) {
      case 'correlate_firespring_session':
        return await correlateFirespringSession(data)
      case 'correlate_lead_submission':
        return await correlateLeadSubmission(data)
      case 'batch_populate_from_firespring':
        return await batchPopulateFromFirespring()
      case 'get_user_journey':
        return await getUserJourney(data.canonical_user_id)
      case 'publish_heartbeat':
        return await publishHeartbeat(data)
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

// Correlate a Firespring visitor session to canonical user
async function correlateFirespringSession(visitorData: any): Promise<Response> {
  const canonicalUserId = generateCanonicalUserId(visitorData)
  const canonicalSessionId = `session_${visitorData.session_id}_${visitorData.visit_time}`

  // Upsert canonical user
  const { data: user, error: userError } = await supabase
    .from('canonical_users')
    .upsert({
      canonical_user_id: canonicalUserId,
      first_seen_at: visitorData.visit_time,
      last_seen_at: visitorData.visit_time,
      primary_ip_address: visitorData.ip_address,
      primary_organization: visitorData.organization,
      primary_location: visitorData.full_location,
      primary_country_code: visitorData.country_code,
      preferred_browser: visitorData.browser,
      preferred_device: visitorData.device,
      merged_session_ids: [visitorData.session_id],
      attributes: {
        firespring_uid: visitorData.unique_visitor_id
      }
    }, {
      onConflict: 'canonical_user_id',
      ignoreDuplicates: false
    })
    .select()
    .single()

  if (userError) {
    console.error('User upsert error:', userError)
  }

  // Insert unified session
  const { data: session, error: sessionError } = await supabase
    .from('unified_sessions')
    .insert({
      canonical_session_id: canonicalSessionId,
      canonical_user_id: canonicalUserId,
      firespring_session_id: visitorData.session_id,
      firespring_unique_visitor_id: visitorData.unique_visitor_id,
      session_start: visitorData.visit_time,
      session_duration_seconds: visitorData.session_duration_seconds,
      page_views: visitorData.actions_count,
      actions_count: visitorData.actions_count,
      is_bounce: visitorData.actions_count <= 1,
      landing_page: visitorData.landing_page,
      exit_page: visitorData.exit_page,
      referrer_type: visitorData.referrer_type,
      referrer_domain: visitorData.referrer_domain,
      referrer_url: visitorData.referrer_url,
      search_query: visitorData.search_query,
      ip_address: visitorData.ip_address,
      country_code: visitorData.country_code,
      city: visitorData.city,
      state: visitorData.state,
      full_location: visitorData.full_location,
      organization: visitorData.organization,
      latitude: visitorData.latitude,
      longitude: visitorData.longitude,
      browser: visitorData.browser,
      os: visitorData.os,
      device: visitorData.device,
      screen_resolution: visitorData.screen_resolution,
      language: visitorData.language,
      session_data: visitorData.full_visitor_data || {}
    })
    .select()
    .single()

  if (sessionError) {
    // Session might already exist (duplicate batch container)
    if (sessionError.code === '23505') {
      return new Response(JSON.stringify({
        message: 'Session already exists (duplicate batch)',
        canonical_session_id: canonicalSessionId,
        canonical_user_id: canonicalUserId,
        duplicate: true
      }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    throw sessionError
  }

  // Broadcast to Realtime channel
  await supabase.channel('session-tracking').send({
    type: 'broadcast',
    event: 'new_session',
    payload: {
      canonical_user_id: canonicalUserId,
      canonical_session_id: canonicalSessionId,
      referrer_type: visitorData.referrer_type,
      location: visitorData.full_location
    }
  })

  return new Response(JSON.stringify({
    message: 'Session correlated successfully',
    canonical_user_id: canonicalUserId,
    canonical_session_id: canonicalSessionId,
    user, session
  }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  })
}

// Correlate lead submission to existing session/user
async function correlateLeadSubmission(leadData: any): Promise<Response> {
  const { email, phone, name, company, message, mmp_lead_id } = leadData

  // Try to find recent session by IP or email
  const lookbackMinutes = 60
  const { data: recentSessions } = await supabase
    .from('unified_sessions')
    .select('canonical_session_id, canonical_user_id')
    .gte('session_start', new Date(Date.now() - lookbackMinutes * 60000).toISOString())
    .order('session_start', { ascending: false })
    .limit(10)

  let canonicalUserId: string
  let canonicalSessionId: string | null = null

  if (recentSessions && recentSessions.length > 0) {
    // Attribute to most recent session
    canonicalSessionId = recentSessions[0].canonical_session_id
    canonicalUserId = recentSessions[0].canonical_user_id
  } else {
    // Create new user from lead data
    canonicalUserId = `user_lead_${Date.now()}`

    await supabase.from('canonical_users').insert({
      canonical_user_id: canonicalUserId,
      first_seen_at: new Date().toISOString(),
      last_seen_at: new Date().toISOString(),
      converted_to_lead: true,
      lead_id: mmp_lead_id,
      conversion_timestamp: new Date().toISOString()
    })
  }

  // Insert lead submission
  const { data: submission, error } = await supabase
    .from('session_lead_submissions')
    .insert({
      canonical_session_id: canonicalSessionId,
      canonical_user_id: canonicalUserId,
      mmp_lead_id: mmp_lead_id,
      form_type: 'contact_form',
      submitted_at: new Date().toISOString(),
      name, email, phone, company, message,
      lead_status: 'new',
      form_data: leadData
    })
    .select()
    .single()

  if (error) throw error

  // Update user conversion status
  await supabase
    .from('canonical_users')
    .update({
      converted_to_lead: true,
      lead_id: mmp_lead_id,
      conversion_timestamp: new Date().toISOString()
    })
    .eq('canonical_user_id', canonicalUserId)

  // Broadcast conversion event
  await supabase.channel('conversions').send({
    type: 'broadcast',
    event: 'lead_submitted',
    payload: {
      canonical_user_id: canonicalUserId,
      mmp_lead_id: mmp_lead_id,
      email, name
    }
  })

  return new Response(JSON.stringify({
    message: 'Lead submission correlated',
    canonical_user_id: canonicalUserId,
    canonical_session_id: canonicalSessionId,
    submission
  }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  })
}

// Batch populate canonical tables from existing Firespring data
async function batchPopulateFromFirespring(): Promise<Response> {
  const { data: visitors, error } = await supabase
    .from('firespring_visitors_detailed')
    .select('*')
    .limit(1000)

  if (error) throw error

  const results = { users: 0, sessions: 0, errors: 0 }

  for (const visitor of visitors || []) {
    try {
      await correlateFirespringSession(visitor)
      results.sessions++
    } catch (e) {
      results.errors++
      console.error('Error processing visitor:', e)
    }
  }

  return new Response(JSON.stringify({
    message: 'Batch populate complete',
    ...results
  }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  })
}

// Get complete user journey
async function getUserJourney(canonicalUserId: string): Promise<Response> {
  const { data: user } = await supabase
    .from('canonical_users')
    .select('*')
    .eq('canonical_user_id', canonicalUserId)
    .single()

  const { data: sessions } = await supabase
    .from('unified_sessions')
    .select('*')
    .eq('canonical_user_id', canonicalUserId)
    .order('session_start', { ascending: true })

  const { data: events } = await supabase
    .from('session_events')
    .select('*')
    .in('canonical_session_id', sessions?.map(s => s.canonical_session_id) || [])
    .order('event_timestamp', { ascending: true })

  const { data: leads } = await supabase
    .from('session_lead_submissions')
    .select('*')
    .eq('canonical_user_id', canonicalUserId)

  const { data: adSpend } = await supabase
    .from('ad_spend_sessions')
    .select('*')
    .eq('canonical_user_id', canonicalUserId)

  return new Response(JSON.stringify({
    user,
    sessions,
    events,
    leads,
    ad_spend: adSpend,
    journey_summary: {
      total_sessions: sessions?.length || 0,
      total_events: events?.length || 0,
      total_leads: leads?.length || 0,
      total_ad_spend: adSpend?.reduce((sum, a) => sum + (a.cost_per_click || 0), 0) || 0,
      converted: user?.converted_to_lead || false
    }
  }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  })
}

// Publish heartbeat from Edge Function/Service Worker
async function publishHeartbeat(heartbeatData: any): Promise<Response> {
  const { component_type, component_id, component_name, status, metrics } = heartbeatData

  const { data, error } = await supabase
    .from('realtime_heartbeats')
    .upsert({
      component_type,
      component_id,
      component_name,
      heartbeat_timestamp: new Date().toISOString(),
      status: status || 'healthy',
      cpu_usage: metrics?.cpu_usage,
      memory_usage: metrics?.memory_usage,
      active_connections: metrics?.active_connections,
      requests_per_minute: metrics?.requests_per_minute,
      error_rate: metrics?.error_rate,
      is_leader: metrics?.is_leader || false,
      quorum_size: metrics?.quorum_size,
      quorum_members: metrics?.quorum_members,
      version: metrics?.version,
      region: metrics?.region,
      metadata: metrics?.metadata || {}
    }, {
      onConflict: 'component_type,component_id'
    })
    .select()
    .single()

  if (error) throw error

  // Broadcast to heartbeat channel
  await supabase.channel('system-health').send({
    type: 'broadcast',
    event: 'heartbeat',
    payload: {
      component_type,
      component_id,
      status,
      timestamp: new Date().toISOString()
    }
  })

  return new Response(JSON.stringify({
    message: 'Heartbeat published',
    data
  }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  })
}

console.log('Session Correlator loaded - Canonical user tracking enabled')
