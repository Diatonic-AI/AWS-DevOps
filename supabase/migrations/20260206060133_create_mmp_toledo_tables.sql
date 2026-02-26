-- MMP Toledo DynamoDB to Supabase Migration
-- This migration creates public tables that replicate the DynamoDB schema
-- for MMP Toledo lead generation system and Firespring integration

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- MMP Toledo Lead Generation Tables

-- 1. MMP Toledo Leads
CREATE TABLE public.mmp_toledo_leads (
  -- Primary fields
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id VARCHAR NOT NULL UNIQUE,  -- Business identifier
  
  -- Contact information
  name VARCHAR,
  email VARCHAR,
  phone VARCHAR,
  company VARCHAR,
  message TEXT,
  
  -- Lead tracking
  source VARCHAR,
  campaign_id VARCHAR,
  status VARCHAR DEFAULT 'new',
  
  -- Metadata
  metadata JSONB DEFAULT '{}',
  
  -- DynamoDB compatibility fields
  dynamodb_pk VARCHAR,  -- Original DynamoDB partition key
  dynamodb_sk VARCHAR,  -- Original DynamoDB sort key
  dynamodb_gsi_data JSONB DEFAULT '{}',  -- GSI data from DynamoDB
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. MMP Toledo OTP (One-Time Password) Verification
CREATE TABLE public.mmp_toledo_otp (
  -- Primary fields
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  otp_id VARCHAR NOT NULL UNIQUE,  -- Business identifier
  
  -- OTP details
  phone_number VARCHAR NOT NULL,
  otp_code VARCHAR NOT NULL,
  status VARCHAR DEFAULT 'pending',
  attempts INTEGER DEFAULT 0,
  max_attempts INTEGER DEFAULT 3,
  
  -- Timing
  expires_at TIMESTAMPTZ NOT NULL,
  verified_at TIMESTAMPTZ,
  
  -- Metadata
  metadata JSONB DEFAULT '{}',
  
  -- DynamoDB compatibility
  dynamodb_pk VARCHAR,
  dynamodb_sk VARCHAR,
  ttl INTEGER,  -- TTL from DynamoDB
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Firespring Integration Tables

-- 3. Firespring Actions
CREATE TABLE public.firespring_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  action_id VARCHAR NOT NULL UNIQUE,
  action_type VARCHAR,
  action_data JSONB DEFAULT '{}',
  status VARCHAR,
  
  -- DynamoDB compatibility
  dynamodb_pk VARCHAR,
  dynamodb_sk VARCHAR,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Firespring Extraction Jobs
CREATE TABLE public.firespring_extraction_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id VARCHAR NOT NULL UNIQUE,
  job_type VARCHAR,
  status VARCHAR,
  progress JSONB DEFAULT '{}',
  results JSONB DEFAULT '{}',
  error_message TEXT,
  
  -- DynamoDB compatibility
  dynamodb_pk VARCHAR,
  dynamodb_sk VARCHAR,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Firespring Network State
CREATE TABLE public.firespring_network_state (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  node_id VARCHAR NOT NULL UNIQUE,
  node_type VARCHAR,
  state_data JSONB DEFAULT '{}',
  last_seen_at TIMESTAMPTZ,
  
  -- DynamoDB compatibility
  dynamodb_pk VARCHAR,
  dynamodb_sk VARCHAR,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Firespring Searches
CREATE TABLE public.firespring_searches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  search_id VARCHAR NOT NULL UNIQUE,
  search_query VARCHAR,
  search_type VARCHAR,
  results_count INTEGER DEFAULT 0,
  search_metadata JSONB DEFAULT '{}',
  
  -- DynamoDB compatibility
  dynamodb_pk VARCHAR,
  dynamodb_sk VARCHAR,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Firespring Segments
CREATE TABLE public.firespring_segments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  segment_id VARCHAR NOT NULL UNIQUE,
  segment_name VARCHAR,
  segment_criteria JSONB DEFAULT '{}',
  member_count INTEGER DEFAULT 0,
  
  -- DynamoDB compatibility
  dynamodb_pk VARCHAR,
  dynamodb_sk VARCHAR,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. Firespring Traffic Sources
CREATE TABLE public.firespring_traffic_sources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_id VARCHAR NOT NULL UNIQUE,
  source_name VARCHAR,
  source_type VARCHAR,
  traffic_data JSONB DEFAULT '{}',
  
  -- DynamoDB compatibility
  dynamodb_pk VARCHAR,
  dynamodb_sk VARCHAR,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. Firespring Visitors
CREATE TABLE public.firespring_visitors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  visitor_id VARCHAR NOT NULL UNIQUE,
  session_data JSONB DEFAULT '{}',
  page_views INTEGER DEFAULT 0,
  last_visit_at TIMESTAMPTZ,
  
  -- DynamoDB compatibility
  dynamodb_pk VARCHAR,
  dynamodb_sk VARCHAR,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create Performance Indexes

-- MMP Toledo Leads indexes
CREATE INDEX idx_mmp_toledo_leads_email ON public.mmp_toledo_leads(email) WHERE email IS NOT NULL;
CREATE INDEX idx_mmp_toledo_leads_phone ON public.mmp_toledo_leads(phone) WHERE phone IS NOT NULL;
CREATE INDEX idx_mmp_toledo_leads_status ON public.mmp_toledo_leads(status);
CREATE INDEX idx_mmp_toledo_leads_source ON public.mmp_toledo_leads(source) WHERE source IS NOT NULL;
CREATE INDEX idx_mmp_toledo_leads_campaign ON public.mmp_toledo_leads(campaign_id) WHERE campaign_id IS NOT NULL;
CREATE INDEX idx_mmp_toledo_leads_created_at ON public.mmp_toledo_leads(created_at);
CREATE INDEX idx_mmp_toledo_leads_dynamodb_pk ON public.mmp_toledo_leads(dynamodb_pk) WHERE dynamodb_pk IS NOT NULL;

-- MMP Toledo OTP indexes
CREATE INDEX idx_mmp_toledo_otp_phone ON public.mmp_toledo_otp(phone_number);
CREATE INDEX idx_mmp_toledo_otp_status ON public.mmp_toledo_otp(status);
CREATE INDEX idx_mmp_toledo_otp_expires_at ON public.mmp_toledo_otp(expires_at);
CREATE INDEX idx_mmp_toledo_otp_created_at ON public.mmp_toledo_otp(created_at);

-- Firespring table indexes
CREATE INDEX idx_firespring_actions_type ON public.firespring_actions(action_type) WHERE action_type IS NOT NULL;
CREATE INDEX idx_firespring_actions_status ON public.firespring_actions(status) WHERE status IS NOT NULL;
CREATE INDEX idx_firespring_jobs_status ON public.firespring_extraction_jobs(status) WHERE status IS NOT NULL;
CREATE INDEX idx_firespring_jobs_type ON public.firespring_extraction_jobs(job_type) WHERE job_type IS NOT NULL;
CREATE INDEX idx_firespring_network_type ON public.firespring_network_state(node_type) WHERE node_type IS NOT NULL;
CREATE INDEX idx_firespring_searches_type ON public.firespring_searches(search_type) WHERE search_type IS NOT NULL;
CREATE INDEX idx_firespring_segments_name ON public.firespring_segments(segment_name) WHERE segment_name IS NOT NULL;
CREATE INDEX idx_firespring_sources_type ON public.firespring_traffic_sources(source_type) WHERE source_type IS NOT NULL;

-- Enable Row Level Security (RLS) for all tables
ALTER TABLE public.mmp_toledo_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mmp_toledo_otp ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.firespring_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.firespring_extraction_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.firespring_network_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.firespring_searches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.firespring_segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.firespring_traffic_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.firespring_visitors ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for service role access (required for Edge Functions)
CREATE POLICY "Service role can access all data" ON public.mmp_toledo_leads
    FOR ALL TO service_role USING (true);
    
CREATE POLICY "Service role can access all data" ON public.mmp_toledo_otp
    FOR ALL TO service_role USING (true);
    
CREATE POLICY "Service role can access all data" ON public.firespring_actions
    FOR ALL TO service_role USING (true);
    
CREATE POLICY "Service role can access all data" ON public.firespring_extraction_jobs
    FOR ALL TO service_role USING (true);
    
CREATE POLICY "Service role can access all data" ON public.firespring_network_state
    FOR ALL TO service_role USING (true);
    
CREATE POLICY "Service role can access all data" ON public.firespring_searches
    FOR ALL TO service_role USING (true);
    
CREATE POLICY "Service role can access all data" ON public.firespring_segments
    FOR ALL TO service_role USING (true);
    
CREATE POLICY "Service role can access all data" ON public.firespring_traffic_sources
    FOR ALL TO service_role USING (true);
    
CREATE POLICY "Service role can access all data" ON public.firespring_visitors
    FOR ALL TO service_role USING (true);

-- Create helper functions for DynamoDB compatibility

-- Function to convert DynamoDB item format to PostgreSQL
CREATE OR REPLACE FUNCTION public.dynamodb_item_to_pg(item JSONB)
RETURNS JSONB AS $$
DECLARE
  result JSONB := '{}'::jsonb;
  key TEXT;
  value JSONB;
BEGIN
  FOR key, value IN SELECT * FROM jsonb_each(item) LOOP
    IF jsonb_typeof(value) = 'object' THEN
      -- Handle DynamoDB type descriptors
      IF value ? 'S' THEN
        result := result || jsonb_build_object(key, value->>'S');
      ELSIF value ? 'N' THEN
        result := result || jsonb_build_object(key, (value->>'N')::numeric);
      ELSIF value ? 'BOOL' THEN
        result := result || jsonb_build_object(key, (value->>'BOOL')::boolean);
      ELSIF value ? 'NULL' THEN
        result := result || jsonb_build_object(key, null);
      ELSIF value ? 'M' THEN
        result := result || jsonb_build_object(key, public.dynamodb_item_to_pg(value->'M'));
      ELSIF value ? 'L' THEN
        -- Handle list items
        result := result || jsonb_build_object(key, value->'L');
      ELSE
        -- If no type descriptor found, use as-is
        result := result || jsonb_build_object(key, value);
      END IF;
    ELSE
      -- Use value as-is if not an object
      result := result || jsonb_build_object(key, value);
    END IF;
  END LOOP;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Create triggers to automatically update timestamps
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add update triggers to all tables
CREATE TRIGGER update_mmp_toledo_leads_updated_at 
    BEFORE UPDATE ON public.mmp_toledo_leads 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
    
CREATE TRIGGER update_mmp_toledo_otp_updated_at 
    BEFORE UPDATE ON public.mmp_toledo_otp 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
    
CREATE TRIGGER update_firespring_actions_updated_at 
    BEFORE UPDATE ON public.firespring_actions 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
    
CREATE TRIGGER update_firespring_extraction_jobs_updated_at 
    BEFORE UPDATE ON public.firespring_extraction_jobs 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
    
CREATE TRIGGER update_firespring_network_state_updated_at 
    BEFORE UPDATE ON public.firespring_network_state 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
    
CREATE TRIGGER update_firespring_searches_updated_at 
    BEFORE UPDATE ON public.firespring_searches 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
    
CREATE TRIGGER update_firespring_segments_updated_at 
    BEFORE UPDATE ON public.firespring_segments 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
    
CREATE TRIGGER update_firespring_traffic_sources_updated_at 
    BEFORE UPDATE ON public.firespring_traffic_sources 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
    
CREATE TRIGGER update_firespring_visitors_updated_at 
    BEFORE UPDATE ON public.firespring_visitors 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Create a view for active leads
CREATE VIEW public.active_mmp_toledo_leads AS
SELECT 
    id,
    lead_id,
    name,
    email,
    phone,
    company,
    message,
    source,
    campaign_id,
    status,
    created_at,
    updated_at
FROM public.mmp_toledo_leads
WHERE status NOT IN ('archived', 'deleted', 'spam')
ORDER BY created_at DESC;

-- Create a view for recent OTP requests
CREATE VIEW public.recent_otp_requests AS
SELECT 
    id,
    otp_id,
    phone_number,
    status,
    attempts,
    max_attempts,
    expires_at,
    verified_at,
    created_at
FROM public.mmp_toledo_otp
WHERE created_at > NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;

-- Default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON ROUTINES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;