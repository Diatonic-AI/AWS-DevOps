# AWS Resource Assignment Report

Generated: 2026-01-12

## Organization Structure

| OU | OU ID | Purpose |
|----|-------|---------|
| Root | r-295b | Organization root |
| Development | ou-295b-03sccrms | Development environments |
| Business Units | ou-295b-c89lssnu | Business unit accounts |
| Diatonic Instances | ou-295b-jdth2cwx | Diatonic service accounts |
| **Client Organizations** | **ou-295b-jwnuwyen** | **Client-facing resources** |
| Technology | ou-295b-u9tfnyvh | Internal platform tools |

## Client Organization Assignments

### 1. MMP-Toledo (Minute Man Press Toledo)

**Status:** ✅ Fully Tagged

| Resource Type | Resource ID | Name | Tags Applied |
|--------------|-------------|------|--------------|
| AWS Account | 455303857245 | Minute Man Press Toledo | N/A (Account level) |
| Amplify App | dh9lr01l0snay | mmp-toledo-funnel-amplify | ✅ Complete |
| AppSync API | sqiqbtbugvfabolqwdt4rz3dla | amplifyData (main) | ✅ Auto-tagged |
| AppSync API | h6a66mxndnhc7h3o4kldil67oa | amplifyData (develop) | ✅ Auto-tagged |
| S3 Bucket | mmp-toledo-billing-portal | Billing Portal | ✅ Tagged |
| S3 Bucket | mmp-toledo-shared-media | Shared Media | ✅ Tagged |
| S3 Bucket | firespring-backdoor-data-30511389 | Firespring Data | ✅ Tagged |
| S3 Bucket | firespring-backdoor-lambda-30511389 | Firespring Lambda | ✅ Tagged |

**DynamoDB Tables (auto-associated via AppSync):**
- All tables with suffix `-sqiqbtbugvfabolqwdt4rz3dla-NONE` (main branch)
- All tables with suffix `-h6a66mxndnhc7h3o4kldil67oa-NONE` (develop branch)

---

### 2. 1st-Commercial-Credit

**Status:** ✅ Tagged and Configured

| Resource Type | Resource ID | Name | Tags Applied |
|--------------|-------------|------|--------------|
| Amplify App | d3fmbf4wquqbgg | unified-monorepo | ✅ Complete |

**Configuration File:** `platform/config/clients/1st-commercial-credit.yaml`

**Tags Applied:**
- `ClientOrganization: 1st-Commercial-Credit`
- `ClientAccount: 313476888312`
- `ClientOU: ou-295b-jwnuwyen`
- `Environment: production`
- `BillingProject: 1st-commercial-credit`

---

### 3. LSG-Global (Live Smart Growth)

**Status:** ✅ Tagged and Configured

| Resource Type | Resource ID | Name | Tags Applied |
|--------------|-------------|------|--------------|
| AWS Account | 884537046127 | Live Smart Growth | N/A (Account level) |
| Amplify App | d37cj2a5s8sjy1 | LSGGlobalKnowledeLib | ✅ Complete |
| S3 Bucket | amplify-lsgglobalknowledelib-* | Deployment buckets | Auto-tagged by Amplify |

**Configuration File:** `platform/config/clients/lsg-global.yaml`

**Tags Applied:**
- `ClientOrganization: LSG-Global`
- `ClientAccount: 884537046127`
- `ClientOU: ou-295b-jwnuwyen`
- `Environment: production`
- `BillingProject: lsg-global`

---

### 4. Internal Platform (Client Portal)

**Status:** ✅ Tagged

| Resource Type | Resource ID | Name | Tags Applied |
|--------------|-------------|------|--------------|
| Amplify App | d3a9pfwsggqz5 | client-portal | ✅ Complete |
| AppSync API | cx534ivqwrctjb73xc3jszilgq | amplifyData (dev) | ✅ Auto-tagged |

**Tags Applied:**
- `ClientOrganization: Internal`
- `ClientOU: ou-295b-u9tfnyvh` (Technology OU)
- `BillingProject: internal-platform`

---

## Cost Allocation Tags

The following tags have been activated for cost allocation reporting:

| Tag Key | Status | Purpose |
|---------|--------|---------|
| `ClientOrganization` | ✅ Active | Primary cost grouping by client |
| `BillingProject` | ✅ Active | Project-level cost tracking |
| `Environment` | ✅ Active | Environment cost comparison |
| `Service` | ✅ Active | Service-level cost analysis |

**Note:** Cost allocation tags may take up to 24 hours to appear in Cost Explorer.

---

## Partner Central Integration Status

| Client | Partner Central Ready | Configuration |
|--------|----------------------|---------------|
| MMP-Toledo | ✅ Ready | `platform/config/clients/mmp-toledo.yaml` |
| 1st-Commercial-Credit | ✅ Ready | `platform/config/clients/1st-commercial-credit.yaml` |
| LSG-Global | ✅ Ready | `platform/config/clients/lsg-global.yaml` |

**Next Steps for Partner Central:**
1. Configure Partner Central API credentials in AWS Secrets Manager
2. Link the AWS account to Partner Central
3. Create opportunities for each client via `connector-partner-central` service
4. Set up metering for billing via `connector-marketplace` service

---

## Tagging Policy Reference

See: `docs/spec/resource-tagging-policy.md`

## Files Created

- `docs/spec/resource-tagging-policy.md` - Standardized tagging policy
- `platform/config/clients/mmp-toledo.yaml` - MMP Toledo configuration
- `platform/config/clients/1st-commercial-credit.yaml` - 1st Commercial Credit configuration
- `platform/config/clients/lsg-global.yaml` - LSG Global configuration
