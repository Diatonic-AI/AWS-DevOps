-- Optional: Enable RLS for strict tenant isolation inside pooled DB.
-- Assumes application sets `app.tenant_id` per request via DB session.
alter table tenants enable row level security;
alter table users enable row level security;
alter table roles enable row level security;
alter table user_roles enable row level security;
alter table policies enable row level security;
alter table connectors enable row level security;
alter table ingestion_runs enable row level security;
alter table partnercentral_opportunities enable row level security;
alter table marketplace_products enable row level security;
alter table meter_usage enable row level security;
alter table audit_log enable row level security;

create policy tenant_isolation_users on users
  using (tenant_id::text = current_setting('app.tenant_id', true));

-- Repeat pattern for each table (omitted for brevity; generate via migration tool).