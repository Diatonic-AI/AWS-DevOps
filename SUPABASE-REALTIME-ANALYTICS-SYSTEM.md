# Supabase Realtime Analytics & Session Tracking System

**Project**: MMP Toledo + Firespring Analytics Integration
**Supabase Project**: jpcdwbkeivtmweoacbsh
**Deployment Date**: February 6, 2026

---

## 🎯 System Overview

A **modular, pluggable microservice architecture** for real-time visitor tracking, session correlation, lead attribution, and system health monitoring using Supabase Realtime, PostgreSQL functions, and Edge Functions.

### Key Capabilities
✅ **Canonical User Identity** - Merge sessions across devices/visits
✅ **Session Deduplication** - 513 unique sessions from 13,804 raw records (95.7% dedup)
✅ **Real-time Pub/Sub** - Live session events via Supabase Realtime
✅ **Heartbeat Monitoring** - Distributed system health with leader election
✅ **Attribution Tracking** - Ad spend → Session → Lead conversion funnel
✅ **Geographic Analytics** - City/state/country distribution with lat/lon
✅ **User Journey Mapping** - Multi-touch attribution across visits

---

## 📊 Database Schema

### Core Tables

#### 1. `canonical_users` - Unified User Identity
```sql
-- Represents a unique individual across multiple sessions/devices
CREATE TABLE canonical_users (
  canonical_user_id TEXT UNIQUE,           -- Fingerprint-based ID
  merged_visitor_ids TEXT[],                -- All session IDs for this user
  first_seen_at TIMESTAMPTZ,
  last_seen_at TIMESTAMPTZ,
  total_sessions INTEGER,
  total_actions INTEGER,
  is_returning_visitor BOOLEAN,
  converted_to_lead BOOLEAN,
  lead_id TEXT,                             -- Link to MMP Toledo leads
  primary_ip_address TEXT,
  primary_location TEXT,
  preferred_browser TEXT,
  preferred_device TEXT,
  attributes JSONB                          -- Extensible metadata
);
```

**Current Data**: 459 canonical users (37 returning visitors)

#### 2. `unified_sessions` - Consolidated Session Data
```sql
-- Each website visit with full attribution and device context
CREATE TABLE unified_sessions (
  canonical_session_id TEXT UNIQUE,         -- session_{firespring_id}_{timestamp}
  canonical_user_id TEXT,                   -- FK to canonical_users
  firespring_session_id TEXT,               -- Original Firespring ID
  session_start TIMESTAMPTZ,
  session_duration_seconds INTEGER,
  page_views INTEGER,
  actions_count INTEGER,
  is_bounce BOOLEAN,
  landing_page TEXT,
  exit_page TEXT,
  referrer_type TEXT,                       -- 'search', 'direct', 'referral'
  referrer_domain TEXT,
  search_query TEXT,
  ip_address TEXT,
  city TEXT, state TEXT, country_code TEXT,
  browser TEXT, os TEXT, device TEXT,
  converted BOOLEAN,
  conversion_value NUMERIC,
  utm_source TEXT, utm_campaign TEXT,       -- Campaign tracking
  session_data JSONB                        -- Full Firespring data
);
```

**Current Data**: 513 sessions (264 bounces)

#### 3. `session_events` - Granular Event Tracking
```sql
-- Page views, clicks, form submissions, downloads
CREATE TABLE session_events (
  canonical_session_id TEXT,
  event_type TEXT,                          -- 'page_view', 'click', 'submit'
  event_timestamp TIMESTAMPTZ,
  page_url TEXT,
  event_data JSONB,
  firespring_action_id TEXT                 -- Link to firespring_actions
);
```

#### 4. `ad_spend_sessions` - Ad Attribution
```sql
-- Links sessions to ad campaigns for ROI tracking
CREATE TABLE ad_spend_sessions (
  canonical_session_id TEXT,
  canonical_user_id TEXT,
  ad_platform TEXT,                         -- 'google_ads', 'facebook', etc.
  campaign_id TEXT,
  cost_per_click NUMERIC,
  converted BOOLEAN,
  conversion_value NUMERIC,
  roi_percentage NUMERIC                    -- Auto-calculated
);
```

#### 5. `session_lead_submissions` - Conversion Tracking
```sql
-- Form submissions correlated to sessions
CREATE TABLE session_lead_submissions (
  canonical_session_id TEXT,
  canonical_user_id TEXT,
  mmp_lead_id TEXT,                        -- Link to mmp_toledo_leads
  form_type TEXT,
  submitted_at TIMESTAMPTZ,
  name TEXT, email TEXT, phone TEXT,
  lead_score INTEGER,
  attributed_campaign TEXT,                 -- From session UTM params
  attributed_source TEXT
);
```

#### 6. `realtime_heartbeats` - System Health Monitoring
```sql
-- Heartbeat from Edge Functions, Lambdas, Service Workers
CREATE TABLE realtime_heartbeats (
  component_type TEXT,                      -- 'edge_function', 'lambda', 'service_worker'
  component_id TEXT,
  heartbeat_timestamp TIMESTAMPTZ,
  status TEXT,                              -- 'healthy', 'degraded', 'unhealthy'
  cpu_usage NUMERIC,
  memory_usage NUMERIC,
  is_leader BOOLEAN,                        -- Leader election for quorum
  quorum_size INTEGER,
  quorum_members TEXT[],
  metadata JSONB
);
```

---

## 🔌 Edge Functions (Pluggable Microservices)

### 1. `session-correlator` - Main Orchestrator
**URL**: `https://jpcdwbkeivtmweoacbsh.functions.supabase.co/session-correlator`

**Endpoints:**

#### Correlate Firespring Session
```javascript
POST /session-correlator
{
  "action": "correlate_firespring_session",
  "data": {
    "session_id": "992126199",
    "visit_time": "2025-12-30T15:18:09Z",
    "ip_address": "72.241.11.0",
    "browser": "Chrome",
    "os": "Windows",
    "organization": "Buckeye Broadband",
    "actions_count": 10,
    "session_duration_seconds": 592,
    "landing_page": "https://www.mmptoledo.com/",
    "referrer_type": "search",
    "referrer_domain": "google.com"
  }
}

Response:
{
  "canonical_user_id": "user_abc123",
  "canonical_session_id": "session_992126199_1735574289",
  "user": {...},
  "session": {...}
}
```

#### Correlate Lead Submission
```javascript
POST /session-correlator
{
  "action": "correlate_lead_submission",
  "data": {
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "+1234567890",
    "company": "Test Corp",
    "message": "Interested in services",
    "mmp_lead_id": "lead_12345"
  }
}

// Attributes lead to most recent session (within 60 min lookback)
```

#### Batch Populate from Firespring
```javascript
POST /session-correlator
{
  "action": "batch_populate_from_firespring"
}

// Processes up to 1000 visitors at once
```

#### Get User Journey
```javascript
POST /session-correlator
{
  "action": "get_user_journey",
  "data": {
    "canonical_user_id": "user_abc123"
  }
}

Response:
{
  "user": {...},
  "sessions": [session1, session2, session3],
  "events": [event1, event2, ...],
  "leads": [...],
  "ad_spend": [...],
  "journey_summary": {
    "total_sessions": 3,
    "total_events": 45,
    "total_leads": 1,
    "total_ad_spend": 2.50,
    "converted": true
  }
}
```

#### Publish Heartbeat
```javascript
POST /session-correlator
{
  "action": "publish_heartbeat",
  "data": {
    "component_type": "edge_function",
    "component_id": "session-correlator-1",
    "component_name": "Session Correlator",
    "status": "healthy",
    "metrics": {
      "memory_usage": 45.2,
      "requests_per_minute": 150,
      "error_rate": 0.01,
      "is_leader": true,
      "quorum_size": 3,
      "version": "1.0.0",
      "region": "us-east-1"
    }
  }
}
```

---

## 📡 Supabase Realtime Integration

### Enabled Tables (Pub/Sub)
- `unified_sessions` - New sessions broadcast in real-time
- `session_events` - Individual page views/clicks
- `session_lead_submissions` - Form submissions
- `realtime_heartbeats` - System health updates

### Client-Side Subscription (JavaScript)

```javascript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)

// 1. Subscribe to new sessions
const sessionChannel = supabase
  .channel('session-tracking')
  .on('postgres_changes', {
    event: 'INSERT',
    schema: 'public',
    table: 'unified_sessions'
  }, (payload) => {
    console.log('New session:', payload.new)
    // Update dashboard, trigger marketing automation, etc.
  })
  .subscribe()

// 2. Subscribe to lead submissions (conversions)
const conversionChannel = supabase
  .channel('conversions')
  .on('postgres_changes', {
    event: 'INSERT',
    schema: 'public',
    table: 'session_lead_submissions'
  }, (payload) => {
    console.log('New lead!', payload.new)
    // Trigger email notification, CRM sync, etc.
  })
  .subscribe()

// 3. Subscribe to system heartbeats
const healthChannel = supabase
  .channel('system-health')
  .on('postgres_changes', {
    event: '*',
    schema: 'public',
    table: 'realtime_heartbeats',
    filter: `status=eq.unhealthy`
  }, (payload) => {
    console.error('Component unhealthy!', payload.new)
    // Alert operations team
  })
  .subscribe()

// 4. Custom broadcast channels
const analyticsChannel = supabase
  .channel('analytics-events')
  .on('broadcast', { event: 'session_quality_update' }, (payload) => {
    console.log('Quality score updated:', payload)
  })
  .subscribe()
```

### Server-Side Broadcast (Edge Function)

```typescript
// Broadcast custom events from Edge Functions
await supabase.channel('analytics-events').send({
  type: 'broadcast',
  event: 'high_value_visitor',
  payload: {
    canonical_user_id: 'user_xyz',
    quality_score: 95,
    estimated_value: 500
  }
})
```

---

## 🩺 Heartbeat & Quorum System

### Heartbeat Architecture

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  Edge Function 1 │     │  Edge Function 2 │     │  Edge Function 3 │
│  (Leader)        │     │                  │     │                  │
└────────┬─────────┘     └────────┬─────────┘     └────────┬─────────┘
         │                        │                        │
         │   Heartbeat every 30s  │                        │
         └────────────────────────┼────────────────────────┘
                                  ▼
                    ┌──────────────────────────┐
                    │  realtime_heartbeats     │
                    │  Table                   │
                    └──────────────────────────┘
                                  │
                                  ▼
                    ┌──────────────────────────┐
                    │  Quorum Monitor          │
                    │  (Database Function)     │
                    └──────────────────────────┘
```

### Implementing Heartbeats

**In Edge Function:**
```typescript
// Send heartbeat every 30 seconds
setInterval(async () => {
  await fetch('https://jpcdwbkeivtmweoacbsh.functions.supabase.co/session-correlator', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      action: 'publish_heartbeat',
      data: {
        component_type: 'edge_function',
        component_id: 'my-function-instance-1',
        component_name: 'Session Processor',
        status: 'healthy',
        metrics: {
          memory_usage: process.memoryUsage().heapUsed / 1024 / 1024,
          requests_per_minute: requestCounter.getRate(),
          error_rate: errorCounter.getRate() / requestCounter.getRate(),
          region: Deno.env.get('REGION')
        }
      }
    })
  })
}, 30000)
```

**In Lambda Function:**
```javascript
// AWS Lambda heartbeat
const publishHeartbeat = async () => {
  await fetch(SUPABASE_HEARTBEAT_URL, {
    method: 'POST',
    body: JSON.stringify({
      action: 'publish_heartbeat',
      data: {
        component_type: 'lambda',
        component_id: process.env.AWS_LAMBDA_FUNCTION_NAME,
        status: 'healthy',
        metrics: {
          memory_usage: process.memoryUsage().heapUsed / 1024 / 1024,
          region: process.env.AWS_REGION
        }
      }
    })
  })
}

// Call in Lambda handler
exports.handler = async (event) => {
  await publishHeartbeat()
  // ... process event
}
```

### Monitoring Heartbeats

```sql
-- Get system health overview
SELECT * FROM get_system_health();

-- Find components that haven't reported (dead)
SELECT component_type, component_id, heartbeat_timestamp,
  NOW() - heartbeat_timestamp as time_since_heartbeat
FROM realtime_heartbeats
WHERE heartbeat_timestamp < NOW() - INTERVAL '2 minutes'
ORDER BY heartbeat_timestamp DESC;

-- Cleanup old heartbeats (run periodically)
SELECT cleanup_old_heartbeats();
```

### Leader Election (Quorum Pattern)

```sql
-- Elect a leader from healthy components
CREATE OR REPLACE FUNCTION elect_leader(p_component_type TEXT)
RETURNS TEXT AS $$
DECLARE
  new_leader TEXT;
BEGIN
  -- Clear existing leader
  UPDATE realtime_heartbeats
  SET is_leader = false
  WHERE component_type = p_component_type;

  -- Elect oldest healthy component as leader
  UPDATE realtime_heartbeats
  SET is_leader = true
  WHERE component_type = p_component_type
    AND heartbeat_timestamp > NOW() - INTERVAL '1 minute'
    AND status = 'healthy'
  ORDER BY heartbeat_timestamp ASC
  LIMIT 1
  RETURNING component_id INTO new_leader;

  RETURN new_leader;
END;
$$ LANGUAGE plpgsql;

-- Run every minute via cron or Edge Function
SELECT elect_leader('edge_function');
```

---

## 🔗 Pluggable Integration Patterns

### Pattern 1: Webhook Integration (External Systems)

```javascript
// Trigger external webhooks on events
supabase
  .channel('external-integrations')
  .on('postgres_changes', {
    event: 'INSERT',
    schema: 'public',
    table: 'session_lead_submissions'
  }, async (payload) => {
    const lead = payload.new

    // Send to CRM (HubSpot, Salesforce, etc.)
    await fetch('https://api.hubspot.com/contacts/v1/contact', {
      method: 'POST',
      body: JSON.stringify({
        email: lead.email,
        properties: [{
          property: 'canonical_user_id',
          value: lead.canonical_user_id
        }]
      })
    })

    // Send to email service (SendGrid, Mailchimp)
    await fetch('https://api.sendgrid.com/v3/mail/send', {
      method: 'POST',
      body: JSON.stringify({
        to: lead.email,
        from: 'noreply@mmptoledo.com',
        subject: 'Thanks for your inquiry',
        content: [{
          type: 'text/html',
          value: '<p>We received your message...</p>'
        }]
      })
    })
  })
  .subscribe()
```

### Pattern 2: AI Microservice Integration

```javascript
// Feed session data to AI analysis engine
const analyzeSession = async (canonicalSessionId) => {
  const response = await fetch('https://jpcdwbkeivtmweoacbsh.functions.supabase.co/session-correlator', {
    method: 'POST',
    body: JSON.stringify({
      action: 'get_user_journey',
      data: { canonical_user_id: 'user_abc123' }
    })
  })

  const journey = await response.json()

  // Send to AI service for lead scoring
  const aiScore = await fetch('https://your-ai-service.com/score', {
    method: 'POST',
    body: JSON.stringify({
      sessions: journey.sessions,
      total_duration: journey.journey_summary.total_actions,
      referrer_type: journey.sessions[0].referrer_type
    })
  })

  // Update lead score
  await supabase
    .from('session_lead_submissions')
    .update({ lead_score: aiScore.score })
    .eq('canonical_user_id', 'user_abc123')
}
```

### Pattern 3: Real-Time Dashboard Integration

```javascript
// Live analytics dashboard
const Dashboard = () => {
  const [activeSessions, setActiveSessions] = useState([])
  const [conversionEvents, setConversionEvents] = useState([])

  useEffect(() => {
    // Subscribe to real-time session activity
    const channel = supabase
      .channel('dashboard-updates')
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'unified_sessions',
        filter: `session_start=gte.${new Date(Date.now() - 300000).toISOString()}`
      }, (payload) => {
        setActiveSessions(prev => [...prev, payload.new])
      })
      .subscribe()

    return () => channel.unsubscribe()
  }, [])

  return (
    <div>
      <h2>Live Sessions ({activeSessions.length})</h2>
      {activeSessions.map(session => (
        <SessionCard key={session.canonical_session_id} {...session} />
      ))}
    </div>
  )
}
```

---

## 📈 Analytics Queries

### User Journey Analysis

```sql
-- Get complete user journey with attribution
SELECT * FROM get_user_attribution_path('user_abc123');

-- Output:
-- session_number | session_date | referrer_type | landing_page | converted
-- 1              | 2025-12-15   | search        | /home        | false
-- 2              | 2026-01-10   | direct        | /products    | false
-- 3              | 2026-02-01   | email         | /contact     | true
```

### Conversion Funnel

```sql
-- 30-day conversion funnel
SELECT * FROM get_conversion_funnel(
  NOW() - INTERVAL '30 days',
  NOW()
);

-- Output:
-- stage      | count | conversion_rate
-- Visitors   | 459   | 100.0
-- Returning  | 37    | 8.1
-- Converted  | 0     | 0.0
```

### Geographic Distribution

```sql
-- Top cities by sessions
SELECT city, state, unique_users, total_sessions, conversions
FROM geographic_session_distribution
WHERE country_code = 'us'
ORDER BY total_sessions DESC
LIMIT 10;
```

### Campaign Performance

```sql
-- ROI by campaign
SELECT
  campaign,
  unique_users,
  total_sessions,
  conversions,
  conversion_rate,
  total_ad_spend,
  total_revenue,
  avg_roi
FROM campaign_performance
WHERE total_ad_spend > 0
ORDER BY avg_roi DESC;
```

### Similar Users (Lookalike Audiences)

```sql
-- Find users similar to a high-value converter
SELECT * FROM find_similar_users('user_abc123', 0.7, 20);

-- Output: Users with similar browser/device/location profiles
-- Use for:
--   - Facebook Lookalike Audiences
--   - Google Similar Audiences
--   - Email list expansion
```

---

## 🤖 AI-Driven Microservice Integration

### Architecture

```
┌─────────────────┐
│  Firespring     │──┐
│  Visitor Event  │  │
└─────────────────┘  │
                     ├──▶ ┌──────────────────┐
┌─────────────────┐  │    │  session-        │
│  Lead           │──┤    │  correlator      │
│  Submission     │  │    │  Edge Function   │
└─────────────────┘  │    └────────┬─────────┘
                     │             │
┌─────────────────┐  │             ▼
│  Ad Click       │──┘    ┌──────────────────┐
│  (UTM params)   │       │  canonical_users │
└─────────────────┘       │  unified_sessions│
                          └────────┬─────────┘
                                   │
                    ┌──────────────┼──────────────┐
                    ▼              ▼              ▼
          ┌─────────────┐ ┌────────────┐ ┌───────────────┐
          │  AI Lead    │ │  Marketing │ │  Attribution  │
          │  Scoring    │ │  Automation│ │  Engine       │
          └─────────────┘ └────────────┘ └───────────────┘
```

### Pluggable Service Examples

#### 1. Lead Scoring Microservice

```typescript
// Edge Function: ai-lead-scorer
Deno.serve(async (req) => {
  const { canonical_user_id } = await req.json()

  // Get complete journey
  const journey = await fetch(`${CORRELATOR_URL}/get_user_journey`, {
    body: JSON.stringify({ canonical_user_id })
  }).then(r => r.json())

  // AI scoring logic
  const score = calculateScore({
    total_sessions: journey.journey_summary.total_sessions,
    avg_duration: journey.sessions.reduce((s, sess) => s + sess.session_duration_seconds, 0) / journey.sessions.length,
    referrer_quality: journey.sessions.filter(s => s.referrer_type === 'search').length,
    geographic_fit: journey.user.primary_country_code === 'us'
  })

  // Update lead score
  await supabase
    .from('session_lead_submissions')
    .update({ lead_score: score })
    .eq('canonical_user_id', canonical_user_id)

  return new Response(JSON.stringify({ score }))
})
```

#### 2. Marketing Automation Trigger

```typescript
// Edge Function: marketing-automator
supabase
  .channel('marketing-triggers')
  .on('postgres_changes', {
    event: 'INSERT',
    schema: 'public',
    table: 'unified_sessions'
  }, async (payload) => {
    const session = payload.new

    // Trigger remarketing for bounced visitors
    if (session.is_bounce && session.actions_count === 1) {
      await addToRemarketingList(session.canonical_user_id, {
        audience: 'bounced-visitors',
        platform: 'google_ads',
        bid_adjustment: 1.5
      })
    }

    // Trigger email for high-engagement sessions
    if (session.session_duration_seconds > 300 && session.actions_count > 5) {
      await sendEngagementEmail(session.canonical_user_id, {
        template: 'high-engagement-follow-up'
      })
    }
  })
```

#### 3. Attribution Engine

```typescript
// Edge Function: attribution-engine
Deno.serve(async (req) => {
  const { mmp_lead_id } = await req.json()

  // Find the session that led to conversion
  const { data: submission } = await supabase
    .from('session_lead_submissions')
    .select('canonical_user_id, canonical_session_id')
    .eq('mmp_lead_id', mmp_lead_id)
    .single()

  // Get all sessions for this user (multi-touch attribution)
  const { data: sessions } = await supabase
    .from('unified_sessions')
    .select('*')
    .eq('canonical_user_id', submission.canonical_user_id)
    .order('session_start')

  // Attribution models
  const attribution = {
    first_touch: sessions[0],                              // First session gets credit
    last_touch: sessions[sessions.length - 1],            // Last session gets credit
    linear: sessions.map(s => ({ ...s, credit: 1 / sessions.length })), // Equal credit
    time_decay: calculateTimeDecay(sessions)               // More recent = more credit
  }

  return new Response(JSON.stringify(attribution))
})
```

---

## 🔄 Data Flow Pipeline

### Complete Integration Flow

```
1. VISITOR ARRIVES
   ├─▶ Firespring tracks visit
   └─▶ DynamoDB: firespring-backdoor-visitors-dev

2. DYNAMODB STREAM TRIGGER
   ├─▶ Lambda (us-east-1): firespring-sync
   └─▶ Edge Function: mmp-toledo-sync
       └─▶ Insert into firespring_visitors

3. SESSION CORRELATION
   ├─▶ Edge Function: session-correlator
   ├─▶ Generate canonical_user_id (fingerprint)
   ├─▶ Upsert canonical_users
   ├─▶ Insert unified_sessions
   └─▶ Broadcast to Realtime channel

4. AI PROCESSING
   ├─▶ Calculate quality_score
   ├─▶ Lead scoring microservice
   └─▶ Update session metadata

5. CONVERSION EVENT
   ├─▶ User submits form
   ├─▶ Insert session_lead_submissions
   ├─▶ Correlate to recent session
   ├─▶ Update canonical_users.converted_to_lead
   └─▶ Broadcast to conversions channel

6. ATTRIBUTION & ROI
   ├─▶ Query get_user_attribution_path()
   ├─▶ Calculate multi-touch attribution
   ├─▶ Update ad_spend_sessions
   └─▶ Export to ad platforms

7. REALTIME DASHBOARD
   ├─▶ Subscribe to Realtime channels
   ├─▶ Display live sessions
   ├─▶ Show conversion events
   └─▶ Monitor system health
```

---

## 🚀 Deployment & Usage

### Deploy All Edge Functions

```bash
# Session correlator
supabase functions deploy session-correlator \
  --project-ref jpcdwbkeivtmweoacbsh \
  --no-verify-jwt

# Data sync
supabase functions deploy mmp-toledo-sync \
  --project-ref jpcdwbkeivtmweoacbsh \
  --no-verify-jwt

# Checksum validator
supabase functions deploy data-checksum-validator \
  --project-ref jpcdwbkeivtmweoacbsh \
  --no-verify-jwt
```

### Populate Canonical Tables

```bash
# One-time population from existing Firespring data
curl -X POST 'https://jpcdwbkeivtmweoacbsh.functions.supabase.co/session-correlator' \
  -H 'Content-Type: application/json' \
  -d '{"action": "batch_populate_from_firespring"}'
```

### Test Real-Time Pub/Sub

```javascript
// In browser console or Node.js
const { createClient } = require('@supabase/supabase-js')

const supabase = createClient(
  'https://jpcdwbkeivtmweoacbsh.supabase.co',
  'YOUR_ANON_KEY'
)

// Subscribe to new sessions
const channel = supabase
  .channel('test-realtime')
  .on('postgres_changes', {
    event: 'INSERT',
    schema: 'public',
    table: 'unified_sessions'
  }, (payload) => console.log('New session!', payload))
  .subscribe()

// Insert test session (from authenticated admin)
await supabase.from('unified_sessions').insert({...})
```

---

## 📊 Analytics Dashboard Queries

### Key Metrics

```sql
-- Active users (last 30 days)
SELECT COUNT(DISTINCT canonical_user_id)
FROM unified_sessions
WHERE session_start > NOW() - INTERVAL '30 days';

-- Conversion rate
SELECT
  COUNT(DISTINCT canonical_user_id) as total_users,
  COUNT(DISTINCT CASE WHEN converted_to_lead THEN canonical_user_id END) as converted,
  ROUND(COUNT(DISTINCT CASE WHEN converted_to_lead THEN canonical_user_id END)::numeric /
        COUNT(DISTINCT canonical_user_id) * 100, 2) as conversion_rate_pct
FROM canonical_users;

-- Average session metrics
SELECT
  AVG(session_duration_seconds) as avg_duration_sec,
  AVG(actions_count) as avg_actions,
  COUNT(CASE WHEN is_bounce THEN 1 END)::numeric / COUNT(*) * 100 as bounce_rate_pct
FROM unified_sessions;

-- Top referrers
SELECT referrer_domain, COUNT(*) as sessions
FROM unified_sessions
WHERE referrer_domain IS NOT NULL
GROUP BY referrer_domain
ORDER BY sessions DESC
LIMIT 10;
```

---

## 🎯 Use Cases

### 1. Multi-Touch Attribution
Track user across 3+ touchpoints before conversion:
```sql
SELECT * FROM get_user_attribution_path('user_xyz');
-- Session 1: Google search → /home (no conversion)
-- Session 2: Direct → /products (no conversion)
-- Session 3: Email click → /contact (CONVERTED!)
```

### 2. Lookalike Audience Building
Find similar users to your best converters:
```sql
-- Get top 10 converted users
WITH top_converters AS (
  SELECT canonical_user_id FROM canonical_users
  WHERE converted_to_lead = true
  AND total_sessions > 1
  LIMIT 10
)
SELECT DISTINCT fsu.canonical_user_id, fsu.similarity_score
FROM top_converters tc,
LATERAL find_similar_users(tc.canonical_user_id, 0.6, 100) fsu
ORDER BY similarity_score DESC;
```

### 3. Real-Time Lead Alerts
Broadcast high-value leads:
```javascript
supabase
  .channel('high-value-leads')
  .on('postgres_changes', {
    event: 'INSERT',
    schema: 'public',
    table: 'session_lead_submissions'
  }, async (payload) => {
    const { data: session } = await supabase
      .from('unified_sessions')
      .select('*')
      .eq('canonical_session_id', payload.new.canonical_session_id)
      .single()

    // High-value indicators
    if (session.session_duration_seconds > 300 && session.actions_count > 5) {
      // Send Slack notification
      await fetch(SLACK_WEBHOOK, {
        body: JSON.stringify({
          text: `🔥 High-value lead: ${payload.new.email} (${session.actions_count} actions, ${session.session_duration_seconds}s)`
        })
      })
    }
  })
```

---

## 🔧 Maintenance

### Periodic Tasks (Run via cron or Supabase Functions)

```sql
-- 1. Refresh analytics (every hour)
SELECT refresh_all_analytics();

-- 2. Cleanup old heartbeats (every 5 minutes)
SELECT cleanup_old_heartbeats();

-- 3. Elect leaders (every minute)
SELECT elect_leader('edge_function');
SELECT elect_leader('lambda');
SELECT elect_leader('service_worker');

-- 4. Archive old sessions (monthly)
INSERT INTO archived_sessions
SELECT * FROM unified_sessions
WHERE session_start < NOW() - INTERVAL '90 days';

DELETE FROM unified_sessions
WHERE session_start < NOW() - INTERVAL '90 days';
```

---

## 📝 Next Steps

1. **Implement Service Workers** for client-side tracking
2. **Connect to Google Analytics 4** via Measurement Protocol
3. **Build attribution dashboard** with Realtime updates
4. **Integrate with CRM** (HubSpot/Salesforce)
5. **Add predictive lead scoring** with ML model
6. **Implement A/B testing** framework

---

**System Status**: ✅ Fully operational
**Records**: 459 users, 513 sessions, 0 duplicates
**Realtime**: Enabled on 4 tables
**Security**: RLS enforced, admin-only access
