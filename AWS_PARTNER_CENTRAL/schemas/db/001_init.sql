-- Control Plane (PostgreSQL/Aurora). Multi-tenant via tenant_id + optional RLS.
create table if not exists tenants (
  id              uuid primary key,
  slug            text unique not null,
  name            text not null,
  plan            text not null,
  status          text not null default 'active',
  created_at      timestamptz not null default now()
);

create table if not exists users (
  id              uuid primary key,
  tenant_id       uuid not null references tenants(id),
  email           text not null,
  display_name    text,
  status          text not null default 'active',
  created_at      timestamptz not null default now(),
  unique (tenant_id, email)
);

create table if not exists roles (
  id              uuid primary key,
  tenant_id       uuid not null references tenants(id),
  name            text not null,
  unique (tenant_id, name)
);

create table if not exists user_roles (
  tenant_id       uuid not null references tenants(id),
  user_id         uuid not null references users(id),
  role_id         uuid not null references roles(id),
  primary key (tenant_id, user_id, role_id)
);

create table if not exists policies (
  id              uuid primary key,
  tenant_id       uuid not null references tenants(id),
  name            text not null,
  policy_type     text not null, -- rbac|abac|opa
  document_json   jsonb not null,
  created_at      timestamptz not null default now()
);

create table if not exists connectors (
  id              uuid primary key,
  tenant_id       uuid not null references tenants(id),
  name            text not null,
  kind            text not null, -- partner_central|marketplace|crm|etc
  status          text not null default 'enabled',
  config_json     jsonb not null,
  created_at      timestamptz not null default now(),
  unique (tenant_id, name)
);

create table if not exists ingestion_runs (
  id              uuid primary key,
  tenant_id       uuid not null references tenants(id),
  connector_id    uuid not null references connectors(id),
  entity          text not null,
  mode            text not null, -- batch|streaming
  started_at      timestamptz not null default now(),
  ended_at        timestamptz,
  status          text not null default 'running',
  stats_json      jsonb not null default '{}'::jsonb
);

create table if not exists partnercentral_opportunities (
  id              uuid primary key,
  tenant_id       uuid not null references tenants(id),
  pc_opportunity_id text not null,
  lifecycle_json  jsonb not null,
  payload_json    jsonb not null,
  updated_at      timestamptz not null default now(),
  unique (tenant_id, pc_opportunity_id)
);

create table if not exists marketplace_products (
  id              uuid primary key,
  tenant_id       uuid not null references tenants(id),
  entity_id       text not null,        -- Catalog EntityId
  product_code    text,
  payload_json    jsonb not null,
  updated_at      timestamptz not null default now(),
  unique (tenant_id, entity_id)
);

create table if not exists meter_usage (
  id              uuid primary key,
  tenant_id       uuid not null references tenants(id),
  dimension       text not null,
  quantity        bigint not null,
  usage_time      timestamptz not null,
  correlation_id  text,
  payload_json    jsonb not null default '{}'::jsonb,
  created_at      timestamptz not null default now()
);

create table if not exists audit_log (
  id              uuid primary key,
  tenant_id       uuid not null references tenants(id),
  actor_user_id   uuid,
  action          text not null,
  target_type     text,
  target_id       text,
  ticket_id       text,
  metadata_json   jsonb not null default '{}'::jsonb,
  created_at      timestamptz not null default now()
);