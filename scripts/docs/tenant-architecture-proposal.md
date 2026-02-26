# AI Nexus Workbench - Multi-Tenant Architecture Proposal

## Overview
This document outlines the proposed multi-tenant architecture for the AI Nexus Workbench to support organization-level isolation while maintaining security and performance.

## Current vs. Proposed Architecture

### Current: User-Level Isolation
- **DynamoDB Tables**: Keyed by `userId` only
- **S3 Storage**: `private/${aws:userid}/*` isolation
- **Cognito Groups**: Basic group membership via `cognito:groups`

### Proposed: Tenant + User Hierarchy
- **Organizations (Tenants)**: Top-level isolation boundary
- **Users**: Belong to one primary organization + potential guest access
- **Data Partitioning**: `tenantId` + `userId` composite keys
- **File Storage**: `tenants/${tenantId}/users/${userId}/*` structure

## Database Schema Changes

### New DynamoDB Tables

#### 1. Organizations/Tenants Table
```typescript
// ai-nexus-organizations
interface Organization {
  tenantId: string;        // PK: org_<ulid>
  name: string;           // "Acme Corp", "Freelance Projects"
  domain?: string;        // "acme.com" for domain-based routing
  plan: 'free' | 'pro' | 'enterprise';
  settings: {
    maxUsers: number;
    maxStorage: number;   // In GB
    features: string[];   // ["ai-lab", "advanced-analytics"]
  };
  createdAt: string;
  updatedAt: string;
  status: 'active' | 'suspended' | 'trial';
  trialEndsAt?: string;
}
```

#### 2. Enhanced User-Organization Mapping
```typescript
// ai-nexus-user-orgs
interface UserOrganization {
  userId: string;         // PK: user_<cognito-id>
  tenantId: string;       // SK: org_<ulid>
  role: 'owner' | 'admin' | 'member' | 'guest';
  permissions: string[];  // ["read:projects", "write:lab-experiments"]
  joinedAt: string;
  status: 'active' | 'invited' | 'suspended';
  isPrimary: boolean;     // Primary org for this user
}
```

### Modified Existing Tables

All existing tables get enhanced with `tenantId`:

#### Enhanced User Data Table
```typescript
// ai-nexus-user-data
interface UserData {
  tenantId: string;       // New: Add tenant isolation
  userId: string;         // Existing PK
  dataType: string;       // Existing SK
  // ... rest of existing fields
}

// New GSI: TenantDataIndex (tenantId, dataType) for tenant-wide queries
```

## File Storage Architecture

### Enhanced S3 Structure
```
s3://bucket-name/
├── tenants/
│   └── {tenantId}/
│       ├── users/
│       │   └── {userId}/
│       │       ├── private/        # User's private files
│       │       └── shared/         # User's files shared within tenant
│       ├── public/                 # Tenant-wide shared files
│       ├── backups/               # Tenant backups
│       └── templates/             # Tenant-specific templates
├── system/
│   ├── default-templates/         # System-wide templates
│   └── assets/                    # Public system assets
└── temp/                          # Short-lived temp files (1-day TTL)
```

### S3 Bucket Policy Enhancement
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"AWS": "cognito-identity-pool-role-arn"},
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::bucket-name/tenants/${saml:tenantId}/users/${aws:userid}/*",
      "Condition": {
        "StringEquals": {
          "saml:tenantId": "${saml:tenantId}"
        }
      }
    },
    {
      "Effect": "Allow",
      "Principal": {"AWS": "cognito-identity-pool-role-arn"},
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::bucket-name/tenants/${saml:tenantId}/public/*"
    }
  ]
}
```

## Implementation Phases

### Phase 1: Foundation (Week 1-2)
1. **Add tenant concept to Cognito**
   - Custom attributes: `custom:tenantId`, `custom:primaryTenant`
   - Lambda trigger to validate tenant membership on auth

2. **Create organization management tables**
   - Deploy new DynamoDB tables for organizations and user-org mappings
   - Seed with default "personal" tenant for existing users

3. **Update S3 structure**
   - Migrate existing files to new tenant-aware structure
   - Deploy enhanced bucket policies

### Phase 2: Backend Integration (Week 3-4)
1. **Lambda functions enhancement**
   - Add tenant context extraction middleware
   - Update all DynamoDB operations to include tenantId
   - Implement tenant-aware authorization

2. **API Gateway updates**
   - Add tenant validation at the gateway level
   - Rate limiting per tenant
   - Usage analytics per tenant

### Phase 3: Frontend Integration (Week 5-6)
1. **Auth context enhancement**
   - Extract tenant info from ID tokens
   - Add organization switching in UI
   - Update all API calls to include tenant context

2. **Organization management UI**
   - Settings page for organization management
   - User invitation and role management
   - Billing and usage dashboard

### Phase 4: Advanced Features (Week 7-8)
1. **Multi-tenancy features**
   - Cross-tenant guest access (with permissions)
   - Tenant-specific branding and settings
   - Advanced analytics and reporting

2. **Data migration and cleanup**
   - Migrate existing users to default personal tenants
   - Clean up old S3 structures
   - Performance testing and optimization

## Security Considerations

### Data Isolation
- **Database Level**: All queries MUST include tenantId filter
- **Application Level**: Middleware validates user's tenant membership
- **S3 Level**: Path-based isolation with IAM policies
- **API Level**: JWT tokens include tenant claims

### Tenant Switching
- Users can switch between organizations they belong to
- New JWT tokens issued with different tenant context
- Session management tracks current active tenant

### Guest Access
- Users can be invited as guests to other organizations
- Limited permissions (read-only or specific feature access)
- Time-limited access tokens for guests

## Migration Strategy

### Existing Users
1. Create default "Personal" organization for each existing user
2. Set user as owner of their personal organization
3. Migrate existing data with their personal tenantId
4. Update S3 file paths in database references

### Backward Compatibility
- Maintain existing API endpoints during transition
- Add new tenant-aware endpoints gradually
- Feature flags to enable multi-tenant features per user

## Cost Optimization

### DynamoDB
- Use single-table design where possible
- Implement proper GSI design for tenant-wide queries
- Enable auto-scaling for tenant-specific load patterns

### S3
- Implement intelligent tiering for older tenant data
- Use lifecycle policies for tenant-specific retention
- Monitor per-tenant storage usage for billing

### Lambda
- Implement tenant-aware caching
- Use provisioned concurrency for high-usage tenants
- Monitor per-tenant compute costs

## Monitoring and Analytics

### Per-Tenant Metrics
- Storage usage and growth rates
- API usage patterns and rate limits
- Feature adoption and usage analytics
- Performance metrics by tenant size

### Billing and Usage
- Real-time usage tracking per tenant
- Automated billing calculations
- Usage alerts and limit enforcement
- Detailed usage reports for enterprise customers

## Dev/Test Tenant Strategy

### Development Tenants
- `dev-tenant-*` naming convention
- Separate dev/staging DynamoDB tables
- Test data cleanup automation
- Feature flag testing per tenant

### QA and Testing
- Automated tenant creation for test scenarios
- Cross-tenant data leakage testing
- Performance testing with varying tenant sizes
- Security penetration testing for tenant isolation
