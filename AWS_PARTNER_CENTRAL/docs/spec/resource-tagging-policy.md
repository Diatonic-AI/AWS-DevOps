# AWS Resource Tagging Policy

## Overview

This document defines the standardized tagging strategy for AWS resources across all client organizations and internal projects.

## Required Tags

All resources MUST have these tags:

| Tag Key | Description | Example Values |
|---------|-------------|----------------|
| `ClientOrganization` | Client organization identifier | `MMP-Toledo`, `1st-Commercial-Credit`, `LSG-Global` |
| `ClientAccount` | AWS Account ID for the client | `455303857245` |
| `ClientOU` | Organizational Unit ID | `ou-295b-jwnuwyen` |
| `Environment` | Deployment environment | `production`, `staging`, `development`, `sandbox` |
| `Service` | AWS service category | `Amplify`, `DynamoDB`, `S3`, `Lambda`, `AppSync` |
| `Component` | Application component | `Frontend`, `Backend`, `Storage`, `API` |
| `BillingProject` | Cost allocation project code | `mmp-toledo`, `1st-commercial-credit` |
| `ManagedBy` | Management method | `terraform`, `amplify`, `manual`, `cdk` |

## Optional Tags

| Tag Key | Description | Example Values |
|---------|-------------|----------------|
| `AssignedBy` | Who assigned the resource | `aws-cli`, `github-action`, `admin` |
| `AssignedDate` | Date of assignment | `2025-01-12` |
| `CostCenter` | Internal cost center | `CC-001`, `CC-002` |
| `Owner` | Resource owner email | `admin@company.com` |

## Client Organization Mappings

### 1. Minute Man Press Toledo (MMP-Toledo)

| Attribute | Value |
|-----------|-------|
| **Client Organization** | `MMP-Toledo` |
| **AWS Account** | `455303857245` |
| **Client OU** | `ou-295b-jwnuwyen` (Client Organizations) |
| **Billing Project** | `mmp-toledo` |
| **Parent Account** | Steve Heaney Investments (`819087822699`) |

**Resources:**
- Amplify App: `dh9lr01l0snay` (mmp-toledo-funnel-amplify)
- AppSync APIs: `sqiqbtbugvfabolqwdt4rz3dla` (main), `h6a66mxndnhc7h3o4kldil67oa` (develop)
- S3 Buckets: `mmp-toledo-billing-portal`, `mmp-toledo-shared-media*`
- DynamoDB Tables: All tables with suffix `sqiqbtbugvfabolqwdt4rz3dla-NONE` or `h6a66mxndnhc7h3o4kldil67oa-NONE`

### 2. 1st Commercial Credit

| Attribute | Value |
|-----------|-------|
| **Client Organization** | `1st-Commercial-Credit` |
| **AWS Account** | `313476888312` (DiatonicAI - Management) |
| **Client OU** | `ou-295b-jwnuwyen` (Client Organizations) |
| **Billing Project** | `1st-commercial-credit` |

**Resources:**
- Amplify App: `d3fmbf4wquqbgg` (unified-monorepo)
- Future: Dedicated backend resources

### 3. LSG Global Knowledge Library

| Attribute | Value |
|-----------|-------|
| **Client Organization** | `LSG-Global` |
| **AWS Account** | `884537046127` (Live Smart Growth) |
| **Client OU** | `ou-295b-jwnuwyen` (Client Organizations) |
| **Billing Project** | `lsg-global` |

**Resources:**
- Amplify App: `d37cj2a5s8sjy1` (LSGGlobalKnowledeLib)
- S3 Buckets: `amplify-lsgglobalknowledelib-*`, `amplify-lsgglobalknowledg-lsginvoicesbucket*`

### 4. Client Portal (Internal)

| Attribute | Value |
|-----------|-------|
| **Client Organization** | `Internal` |
| **AWS Account** | `313476888312` (DiatonicAI - Management) |
| **Client OU** | `ou-295b-u9tfnyvh` (Technology) |
| **Billing Project** | `internal-platform` |

**Resources:**
- Amplify App: `d3a9pfwsggqz5` (client-portal)
- AppSync API: `cx534ivqwrctjb73xc3jszilgq` (dev branch)
- DynamoDB Tables: All tables with suffix `cx534ivqwrctjb73xc3jszilgq-NONE`

### 5. Firespring Backend (MMP-Toledo)

| Attribute | Value |
|-----------|-------|
| **Client Organization** | `MMP-Toledo` |
| **Billing Project** | `mmp-toledo` |

**Resources:**
- S3 Buckets: `firespring-backdoor-data-30511389`, `firespring-backdoor-lambda-30511389`

## Cost Allocation Tags

Enable these tags in AWS Cost Explorer for cost allocation:

1. `ClientOrganization` - Primary cost grouping
2. `BillingProject` - Project-level cost tracking
3. `Environment` - Environment cost comparison
4. `Service` - Service-level cost analysis

## Tagging Commands Reference

### Tag Amplify App
```bash
aws amplify tag-resource \
  --resource-arn arn:aws:amplify:us-east-1:ACCOUNT_ID:apps/APP_ID \
  --tags \
    ClientOrganization=ORG_NAME \
    ClientAccount=ACCOUNT_ID \
    ClientOU=ou-295b-jwnuwyen \
    Environment=production \
    Service=Amplify \
    Component=Frontend \
    BillingProject=PROJECT_CODE \
    ManagedBy=terraform
```

### Tag S3 Bucket
```bash
aws s3api put-bucket-tagging \
  --bucket BUCKET_NAME \
  --tagging 'TagSet=[{Key=ClientOrganization,Value=ORG_NAME},{Key=BillingProject,Value=PROJECT_CODE}]'
```

### Tag DynamoDB Table
```bash
aws dynamodb tag-resource \
  --resource-arn arn:aws:dynamodb:us-east-1:ACCOUNT_ID:table/TABLE_NAME \
  --tags Key=ClientOrganization,Value=ORG_NAME Key=BillingProject,Value=PROJECT_CODE
```

## AWS Organization Structure

```
o-eyf5fcwrr3 (Organization)
└── r-295b (Root)
    ├── ou-295b-03sccrms (Development)
    │   └── 916873234430 (Diatonic Dev)
    ├── ou-295b-c89lssnu (Business Units)
    │   └── 479557895143 (Body Life Luxe Co)
    ├── ou-295b-jdth2cwx (Diatonic Instances)
    │   ├── 038876987371 (Diatonic Visuals)
    │   ├── 824156498500 (Diatonic Online)
    │   └── 842990485193 (Diatonic AI)
    ├── ou-295b-jwnuwyen (Client Organizations) ← PRIMARY CLIENT OU
    │   ├── 819087822699 (Steve Heaney Investments)
    │   ├── 455303857245 (Minute Man Press Toledo)
    │   └── 884537046127 (Live Smart Growth)
    └── ou-295b-u9tfnyvh (Technology)
        └── [Internal tooling]
```

## Partner Central Integration

When creating opportunities in AWS Partner Central:

1. Use `ClientOrganization` tag value as the customer name
2. Use `BillingProject` as the project identifier
3. Link `ClientAccount` to the Partner Central customer record
4. Track engagement via `ClientOU` for organizational reporting
