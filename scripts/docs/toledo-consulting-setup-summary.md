# Toledo Consulting & Contracting LLC - AWS Partner Setup Summary

## Setup Date
**Created:** January 23, 2026

## Company Information
- **Company Name:** Toledo Consulting & Contracting LLC
- **Website:** https://www.toledoconsulting.net/
- **Domain:** toledoconsulting.net
- **UEI:** MKK3NH3NRC95
- **CAGE Code:** 83JT2
- **DUNS:** 155808251
- **Certification:** Veteran-owned business

## Services Offered
- Fractional CTO
- Generative AI consulting
- Project Management
- IT Services & Managed IT
- Cloud Backup solutions
- Network Setup
- Vendor Management
- Enterprise-level solutions

## AWS Organization Structure Created

### 1. Organizational Unit
- **Name:** Partners
- **ID:** `ou-295b-6ku3yklg`
- **ARN:** `arn:aws:organizations::313476888312:ou/o-eyf5fcwrr3/ou-295b-6ku3yklg`
- **Parent:** Root (`r-295b`)

### 2. Resource Group
- **Name:** partners-toledo-consulting
- **ARN:** `arn:aws:resource-groups:us-east-2:313476888312:group/partners-toledo-consulting`
- **Description:** Resource group for Toledo Consulting partnership
- **Tags:**
  - Partner: toledo-consulting
  - CompanyType: contractor
  - Services: ai-consulting
  - Certification: veteran-owned

### 3. IAM Policy
- **Name:** ToledoConsultingPartnerPolicy
- **ARN:** `arn:aws:iam::313476888312:policy/ToledoConsultingPartnerPolicy`
- **Policy ID:** ANPAUR7FNW34HZXTGGMA2
- **Purpose:** Provides controlled access to AWS resources for partner dashboard

#### Policy Permissions Include:
- CloudWatch metrics and alarms (read-only)
- EC2 instance viewing and basic operations (tagged resources only)
- RDS instance viewing and start/stop (tagged resources only)
- S3 bucket listing and location info
- Lambda function viewing and execution (tagged resources only)
- Resource group management for partner-specific resources
- Tag-based resource filtering

### 4. IAM Group
- **Name:** ToledoConsultingPartners
- **ARN:** `arn:aws:iam::313476888312:group/ToledoConsultingPartners`
- **Group ID:** AGPAUR7FNW34AU3RZGQKZ
- **Attached Policy:** ToledoConsultingPartnerPolicy

### 5. IAM User
- **Username:** toledo-consulting-admin
- **User ID:** AIDAUR7FNW34OCWWG4OHY
- **ARN:** `arn:aws:iam::313476888312:user/toledo-consulting-admin`
- **Group Membership:** ToledoConsultingPartners
- **Tags:**
  - Partner: toledo-consulting
  - Company: Toledo-Consulting-LLC
  - Role: admin

#### Login Information
- **Console Access:** Enabled
- **Final Password:** X*d^9LdlwU&Ahh$e ✅ **READY TO USE**
- **Password Status:** Reset completed - use directly without changes

## Access Control Summary

The Toledo Consulting partner has been configured with:

1. **Dashboard Access**: Can view CloudWatch metrics, EC2/RDS/Lambda resources, and S3 buckets
2. **Resource Control**: Can only start/stop/manage resources tagged with `Partner=toledo-consulting`
3. **Resource Group Management**: Full access to their dedicated resource group
4. **Security Boundaries**: All permissions are constrained by resource tags and principal tags

## Next Steps for Custom Dashboard

To create a custom AWS backend dashboard for Toledo Consulting:

1. **Deploy dashboard infrastructure** using resources tagged with `Partner=toledo-consulting`
2. **Set up API Gateway** with partner-specific endpoints
3. **Configure Lambda functions** for dashboard backend logic
4. **Create CloudWatch dashboard** with partner-specific metrics
5. **Set up S3 bucket** for dashboard assets and configurations

All dashboard resources should be tagged appropriately to ensure the partner can access and manage them through their assigned permissions.

## Security Notes

- Partner access is restricted to tagged resources only
- All sensitive operations require additional conditions
- Login requires password reset on first access
- Resource group automatically includes any AWS resources tagged with `Partner=toledo-consulting`

## Account Information
- **AWS Account ID:** 313476888312
- **Organization ID:** o-eyf5fcwrr3
- **Region:** us-east-2