-- MMP Toledo DynamoDB to Supabase Migration
-- This script creates tables to replicate the DynamoDB schema for MMP Toledo and Firespring integration
-- Created: 2026-02-06
-- Project: sbp_973480ddcc0eef6cad5518c1f5fc2beea24b2049

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create schema for organization
CREATE SCHEMA IF NOT EXISTS mmp_toledo;

-- =====================================================
-- MMP TOLEDO CORE TABLES
-- =====================================================

-- MMP Toledo Leads Table (replaces mmp-toledo-leads-prod)
CREATE TABLE IF NOT EXISTS public.mmp_toledo_leads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lead_id TEXT UNIQUE NOT NULL, -- Original DynamoDB key
    name TEXT,
    email TEXT,
    phone TEXT,
    company TEXT,
    message TEXT,
    source TEXT,
    campaign_id TEXT,
    status TEXT DEFAULT 'new',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    metadata JSONB DEFAULT '{}',
    -- DynamoDB compatibility fields
    dynamodb_pk TEXT, -- Original partition key
    dynamodb_sk TEXT, -- Original sort key (if exists)
    dynamodb_gsi_data JSONB DEFAULT '{}' -- GSI data
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_mmp_toledo_leads_email ON public.mmp_toledo_leads(email);
CREATE INDEX IF NOT EXISTS idx_mmp_toledo_leads_phone ON public.mmp_toledo_leads(phone);
CREATE INDEX IF NOT EXISTS idx_mmp_toledo_leads_status ON public.mmp_toledo_leads(status);
CREATE INDEX IF NOT EXISTS idx_mmp_toledo_leads_source ON public.mmp_toledo_leads(source);
CREATE INDEX IF NOT EXISTS idx_mmp_toledo_leads_created_at ON public.mmp_toledo_leads(created_at);
CREATE INDEX IF NOT EXISTS idx_mmp_toledo_leads_lead_id ON public.mmp_toledo_leads(lead_id);

-- MMP Toledo OTP Table (replaces mmp-toledo-otp-prod)
CREATE TABLE IF NOT EXISTS public.mmp_toledo_otp (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    otp_id TEXT UNIQUE NOT NULL, -- Original DynamoDB key
    phone_number TEXT NOT NULL,
    otp_code TEXT NOT NULL,
    status TEXT DEFAULT 'pending', -- pending, verified, expired
    attempts INTEGER DEFAULT 0,
    max_attempts INTEGER DEFAULT 3,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    verified_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB DEFAULT '{}',
    -- DynamoDB compatibility fields
    dynamodb_pk TEXT,
    dynamodb_sk TEXT,
    ttl BIGINT -- DynamoDB TTL field
);

-- Create indexes for OTP table
CREATE INDEX IF NOT EXISTS idx_mmp_toledo_otp_phone ON public.mmp_toledo_otp(phone_number);
CREATE INDEX IF NOT EXISTS idx_mmp_toledo_otp_status ON public.mmp_toledo_otp(status);
CREATE INDEX IF NOT EXISTS idx_mmp_toledo_otp_expires_at ON public.mmp_toledo_otp(expires_at);
CREATE INDEX IF NOT EXISTS idx_mmp_toledo_otp_id ON public.mmp_toledo_otp(otp_id);

-- =====================================================
-- FIRESPRING INTEGRATION TABLES
-- =====================================================

-- Firespring Actions Table
CREATE TABLE IF NOT EXISTS public.firespring_actions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    action_id TEXT UNIQUE NOT NULL,
    action_type TEXT NOT NULL,
    entity_type TEXT,
    entity_id TEXT,
    status TEXT DEFAULT 'pending',
    payload JSONB DEFAULT '{}',
    result JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    -- DynamoDB compatibility fields
    dynamodb_pk TEXT,
    dynamodb_sk TEXT
);

-- Firespring Extraction Jobs Table
CREATE TABLE IF NOT EXISTS public.firespring_extraction_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id TEXT UNIQUE NOT NULL,
    job_type TEXT NOT NULL,
    source_url TEXT,
    target_path TEXT,
    status TEXT DEFAULT 'queued', -- queued, running, completed, failed
    progress DECIMAL(5,2) DEFAULT 0.0,
    total_records INTEGER DEFAULT 0,
    processed_records INTEGER DEFAULT 0,
    config JSONB DEFAULT '{}',
    result JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT,
    -- DynamoDB compatibility fields
    dynamodb_pk TEXT,
    dynamodb_sk TEXT
);

-- Firespring Network State Table
CREATE TABLE IF NOT EXISTS public.firespring_network_state (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    node_id TEXT UNIQUE NOT NULL,
    node_type TEXT NOT NULL,
    endpoint_url TEXT,
    status TEXT DEFAULT 'unknown', -- healthy, unhealthy, unknown
    last_check TIMESTAMP WITH TIME ZONE,
    response_time_ms INTEGER,
    config JSONB DEFAULT '{}',
    health_data JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    -- DynamoDB compatibility fields
    dynamodb_pk TEXT,
    dynamodb_sk TEXT
);

-- Firespring Searches Table
CREATE TABLE IF NOT EXISTS public.firespring_searches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    search_id TEXT UNIQUE NOT NULL,
    query TEXT NOT NULL,
    search_type TEXT,
    filters JSONB DEFAULT '{}',
    results JSONB DEFAULT '{}',
    result_count INTEGER DEFAULT 0,
    execution_time_ms INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    user_id TEXT,
    session_id TEXT,
    -- DynamoDB compatibility fields
    dynamodb_pk TEXT,
    dynamodb_sk TEXT
);

-- Firespring Segments Table (Analytics)
CREATE TABLE IF NOT EXISTS public.firespring_segments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    segment_id TEXT UNIQUE NOT NULL,
    segment_name TEXT NOT NULL,
    description TEXT,
    criteria JSONB NOT NULL DEFAULT '{}',
    user_count INTEGER DEFAULT 0,
    last_calculated TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    -- DynamoDB compatibility fields
    dynamodb_pk TEXT,
    dynamodb_sk TEXT
);

-- Firespring Traffic Sources Table
CREATE TABLE IF NOT EXISTS public.firespring_traffic_sources (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_id TEXT UNIQUE NOT NULL,
    source_name TEXT NOT NULL,
    source_type TEXT, -- organic, paid, direct, social, email, referral
    domain TEXT,
    campaign_id TEXT,
    utm_source TEXT,
    utm_medium TEXT,
    utm_campaign TEXT,
    visitor_count INTEGER DEFAULT 0,
    session_count INTEGER DEFAULT 0,
    conversion_count INTEGER DEFAULT 0,
    date_recorded DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    -- DynamoDB compatibility fields
    dynamodb_pk TEXT,
    dynamodb_sk TEXT
);

-- Firespring Visitors Table
CREATE TABLE IF NOT EXISTS public.firespring_visitors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    visitor_id TEXT UNIQUE NOT NULL,
    session_id TEXT,
    ip_address INET,
    user_agent TEXT,
    first_visit TIMESTAMP WITH TIME ZONE,
    last_visit TIMESTAMP WITH TIME ZONE,
    visit_count INTEGER DEFAULT 1,
    page_views INTEGER DEFAULT 0,
    source_id TEXT,
    country TEXT,
    region TEXT,
    city TEXT,
    device_type TEXT, -- desktop, mobile, tablet
    browser TEXT,
    os TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    -- DynamoDB compatibility fields
    dynamodb_pk TEXT,
    dynamodb_sk TEXT
);

-- =====================================================
-- INDEXES FOR FIRESPRING TABLES
-- =====================================================

-- Firespring Actions indexes
CREATE INDEX IF NOT EXISTS idx_firespring_actions_type ON public.firespring_actions(action_type);
CREATE INDEX IF NOT EXISTS idx_firespring_actions_status ON public.firespring_actions(status);
CREATE INDEX IF NOT EXISTS idx_firespring_actions_created_at ON public.firespring_actions(created_at);

-- Firespring Extraction Jobs indexes
CREATE INDEX IF NOT EXISTS idx_firespring_jobs_type ON public.firespring_extraction_jobs(job_type);
CREATE INDEX IF NOT EXISTS idx_firespring_jobs_status ON public.firespring_extraction_jobs(status);
CREATE INDEX IF NOT EXISTS idx_firespring_jobs_created_at ON public.firespring_extraction_jobs(created_at);

-- Firespring Network State indexes
CREATE INDEX IF NOT EXISTS idx_firespring_network_type ON public.firespring_network_state(node_type);
CREATE INDEX IF NOT EXISTS idx_firespring_network_status ON public.firespring_network_state(status);
CREATE INDEX IF NOT EXISTS idx_firespring_network_last_check ON public.firespring_network_state(last_check);

-- Firespring Searches indexes
CREATE INDEX IF NOT EXISTS idx_firespring_searches_type ON public.firespring_searches(search_type);
CREATE INDEX IF NOT EXISTS idx_firespring_searches_created_at ON public.firespring_searches(created_at);
CREATE INDEX IF NOT EXISTS idx_firespring_searches_user_id ON public.firespring_searches(user_id);

-- Firespring Segments indexes
CREATE INDEX IF NOT EXISTS idx_firespring_segments_active ON public.firespring_segments(is_active);
CREATE INDEX IF NOT EXISTS idx_firespring_segments_calculated ON public.firespring_segments(last_calculated);

-- Firespring Traffic Sources indexes
CREATE INDEX IF NOT EXISTS idx_firespring_traffic_type ON public.firespring_traffic_sources(source_type);
CREATE INDEX IF NOT EXISTS idx_firespring_traffic_date ON public.firespring_traffic_sources(date_recorded);
CREATE INDEX IF NOT EXISTS idx_firespring_traffic_campaign ON public.firespring_traffic_sources(campaign_id);

-- Firespring Visitors indexes
CREATE INDEX IF NOT EXISTS idx_firespring_visitors_session ON public.firespring_visitors(session_id);
CREATE INDEX IF NOT EXISTS idx_firespring_visitors_source ON public.firespring_visitors(source_id);
CREATE INDEX IF NOT EXISTS idx_firespring_visitors_last_visit ON public.firespring_visitors(last_visit);
CREATE INDEX IF NOT EXISTS idx_firespring_visitors_device ON public.firespring_visitors(device_type);

-- =====================================================
-- ROW LEVEL SECURITY POLICIES
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE public.mmp_toledo_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mmp_toledo_otp ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.firespring_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.firespring_extraction_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.firespring_network_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.firespring_searches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.firespring_segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.firespring_traffic_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.firespring_visitors ENABLE ROW LEVEL SECURITY;

-- Create policies for service role (for webhooks and edge functions)
CREATE POLICY "Allow service role full access on mmp_toledo_leads" ON public.mmp_toledo_leads
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role full access on mmp_toledo_otp" ON public.mmp_toledo_otp
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role full access on firespring_actions" ON public.firespring_actions
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role full access on firespring_extraction_jobs" ON public.firespring_extraction_jobs
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role full access on firespring_network_state" ON public.firespring_network_state
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role full access on firespring_searches" ON public.firespring_searches
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role full access on firespring_segments" ON public.firespring_segments
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role full access on firespring_traffic_sources" ON public.firespring_traffic_sources
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role full access on firespring_visitors" ON public.firespring_visitors
    FOR ALL USING (auth.role() = 'service_role');

-- =====================================================
-- FUNCTIONS AND TRIGGERS
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_mmp_toledo_leads_updated_at BEFORE UPDATE ON public.mmp_toledo_leads
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_firespring_actions_updated_at BEFORE UPDATE ON public.firespring_actions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_firespring_network_state_updated_at BEFORE UPDATE ON public.firespring_network_state
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_firespring_segments_updated_at BEFORE UPDATE ON public.firespring_segments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_firespring_visitors_updated_at BEFORE UPDATE ON public.firespring_visitors
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- MIGRATION SUPPORT FUNCTIONS
-- =====================================================

-- Function to convert DynamoDB item to PostgreSQL row
CREATE OR REPLACE FUNCTION dynamodb_item_to_pg(item JSONB, table_name TEXT)
RETURNS JSONB AS $$
DECLARE
    result JSONB := '{}'::JSONB;
    key TEXT;
    value JSONB;
BEGIN
    FOR key, value IN SELECT * FROM jsonb_each(item)
    LOOP
        -- Handle DynamoDB type descriptors
        IF value ? 'S' THEN
            result := result || jsonb_build_object(key, value->>'S');
        ELSIF value ? 'N' THEN
            result := result || jsonb_build_object(key, (value->>'N')::NUMERIC);
        ELSIF value ? 'B' THEN
            result := result || jsonb_build_object(key, value->'B');
        ELSIF value ? 'SS' THEN
            result := result || jsonb_build_object(key, value->'SS');
        ELSIF value ? 'NS' THEN
            result := result || jsonb_build_object(key, value->'NS');
        ELSIF value ? 'BS' THEN
            result := result || jsonb_build_object(key, value->'BS');
        ELSIF value ? 'M' THEN
            result := result || jsonb_build_object(key, dynamodb_item_to_pg(value->'M', table_name));
        ELSIF value ? 'L' THEN
            result := result || jsonb_build_object(key, value->'L');
        ELSIF value ? 'NULL' THEN
            result := result || jsonb_build_object(key, null);
        ELSIF value ? 'BOOL' THEN
            result := result || jsonb_build_object(key, (value->>'BOOL')::BOOLEAN);
        ELSE
            result := result || jsonb_build_object(key, value);
        END IF;
    END LOOP;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- COMMENTS FOR DOCUMENTATION
-- =====================================================

COMMENT ON TABLE public.mmp_toledo_leads IS 'MMP Toledo lead generation data migrated from DynamoDB';
COMMENT ON TABLE public.mmp_toledo_otp IS 'OTP verification codes for MMP Toledo lead verification';
COMMENT ON TABLE public.firespring_actions IS 'Firespring integration action tracking';
COMMENT ON TABLE public.firespring_extraction_jobs IS 'Data extraction job status and metadata';
COMMENT ON TABLE public.firespring_network_state IS 'Network node health and status monitoring';
COMMENT ON TABLE public.firespring_searches IS 'Search query tracking and results';
COMMENT ON TABLE public.firespring_segments IS 'Analytics segments for user categorization';
COMMENT ON TABLE public.firespring_traffic_sources IS 'Website traffic source tracking';
COMMENT ON TABLE public.firespring_visitors IS 'Visitor tracking and analytics data';

-- =====================================================
-- SAMPLE DATA (for testing)
-- =====================================================

-- Insert sample MMP Toledo lead (for testing)
INSERT INTO public.mmp_toledo_leads (
    lead_id, name, email, phone, company, message, source, status
) VALUES (
    'lead_sample_001',
    'Test Customer',
    'test@example.com',
    '+1234567890',
    'Test Company',
    'Sample lead for testing',
    'website',
    'new'
) ON CONFLICT (lead_id) DO NOTHING;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- Grant read access to authenticated users (adjust as needed)
GRANT SELECT ON ALL TABLES IN SCHEMA public TO authenticated;