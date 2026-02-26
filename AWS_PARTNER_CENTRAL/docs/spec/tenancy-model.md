# Tenancy Model

## 1) Hierarchy

```
Enterprise (billing entity)
  └─ Organization (business unit)
       └─ Workspace (project/team scope)
            └─ User (individual identity)
```

### 1.1 Entity Definitions

| Entity | Purpose | Isolation Boundary |
|--------|---------|-------------------|
| Enterprise | Billing, contracts, SLAs | Account-level |
| Organization | Department/BU grouping | Data prefix + RLS |
| Workspace | Project-scoped resources | Schema/prefix partition |
| User | Individual access | RBAC + ABAC policies |

## 2) Isolation Model: Pooled Compute, Isolated Data

### 2.1 Rationale
- **Cost efficiency**: Shared infrastructure reduces per-tenant overhead
- **Operational simplicity**: Single deployment pipeline
- **Security**: Data isolation via application-layer controls

### 2.2 Implementation Patterns

| Resource | Isolation Method |
|----------|-----------------|
| RDS Aurora | `tenant_id` column + RLS policies |
| S3 Data Lake | Prefix partitioning: `s3://bucket/{tenant_id}/...` |
| Redshift | Schema-per-tenant (enterprise) or RLS (org) |
| EventBridge | Tenant ID in event payload + rule filtering |
| Secrets Manager | Path prefix: `/{env}/{tenant_id}/...` |

### 2.3 RLS Implementation

```sql
-- Session variable set by application layer
SET app.tenant_id = 'tenant-uuid-here';

-- Policy applied to all tables
CREATE POLICY tenant_isolation ON users
  USING (tenant_id::text = current_setting('app.tenant_id', true));
```

## 3) Tenant Lifecycle

### 3.1 Provisioning Flow

```
1. Create tenant record (tenant-service)
   ↓
2. Allocate plan/entitlements
   ↓
3. Create S3 prefixes + bucket policies
   ↓
4. Initialize Redshift schema (if enterprise tier)
   ↓
5. Seed default roles + policies
   ↓
6. Configure connectors (optional)
   ↓
7. Emit `tenant.provisioned` event
```

### 3.2 Deprovisioning Flow

```
1. Mark tenant status = 'pending_deletion'
   ↓
2. Disable all connectors
   ↓
3. Export data (if requested)
   ↓
4. Purge data lake prefixes
   ↓
5. Drop Redshift schema
   ↓
6. Delete database records (cascade)
   ↓
7. Remove secrets
   ↓
8. Emit `tenant.deleted` event
```

### 3.3 Plan Transitions

| From | To | Actions |
|------|-----|---------|
| Foundation | Scale | Increase limits, enable AI features |
| Scale | Enterprise | Create dedicated Redshift schema, custom models |
| Any | Downgrade | Validate usage within new limits, archive excess |

## 4) Multi-Tenant Data Access

### 4.1 Request Context

Every authenticated request includes:
```json
{
  "tid": "tenant-uuid",
  "oid": "org-uuid",
  "wid": "workspace-uuid",
  "uid": "user-uuid",
  "roles": ["analyst", "operator"],
  "permissions": ["read:opportunities", "write:connectors"]
}
```

### 4.2 Context Propagation

- **API Gateway**: JWT claims → Lambda authorizer → context header
- **Service mesh**: Propagate `X-Tenant-Context` header
- **Database**: Set session variable before queries
- **Events**: Include tenant context in CloudEvents `subject`

## 5) Cross-Tenant Patterns

### 5.1 When Allowed
- Platform-level analytics (aggregated, anonymized)
- Support/admin access (with explicit audit logging)
- Enterprise parent viewing child org data

### 5.2 Controls
- Explicit `cross_tenant_access` permission required
- Enhanced audit logging (reason field)
- Time-bounded access tokens

## 6) Tenant Configuration

### 6.1 Tenant-Specific Settings

```yaml
# tenants.yaml example
tenants:
  - id: "tenant-123"
    slug: "acme-corp"
    name: "ACME Corporation"
    plan: "enterprise"
    settings:
      data_retention_days: 730
      pii_redaction: "aggressive"
      allowed_regions: ["us-east-1", "eu-west-1"]
      custom_branding:
        logo_url: "https://..."
        primary_color: "#1a2b3c"
```

### 6.2 Feature Flags per Tenant

```yaml
feature_flags:
  tenant-123:
    ai_recommendations: true
    beta_dashboards: true
    partner_central_write: false  # Still in approval mode
```

## 7) Compliance Considerations

### 7.1 Data Residency
- Tenant can specify allowed regions
- Data lake partitioning respects regional boundaries
- Cross-region replication disabled by default

### 7.2 Data Retention
- Configurable per tenant (within plan limits)
- Minimum retention for compliance (audit logs: 7 years)
- Automated lifecycle policies

### 7.3 Audit Trail
- All tenant operations logged
- Logs include tenant context
- Cross-tenant access requires justification
