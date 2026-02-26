# AWS Complete Infrastructure Inventory - Summary Report

**Generated:** 2026-01-24 at 17:57 UTC  
**Scan Duration:** 2,672 seconds (44.5 minutes)  
**Organization:** o-eyf5fcwrr3  
**Master Account:** 313476888312 (DiatonicAI)

---

## Organization Overview

### Accounts Scanned: 9
1. **Diatonic Visuals** (038876987371)
2. **DiatonicAI** (313476888312) - Master Account
3. **Steve Heaney Investments** (819087822699)
4. **Live Smart Growth** (884537046127)
5. **Body Life Luxe Co** (479557895143)
6. **Minute Man Press Toledo** (455303857245)
7. **Diatonic Online** (824156498500)
8. **Diatonic AI** (842990485193)
9. **Diatonic Dev** (916873234430)

### Regions Scanned: 3 per account
- **us-east-1** (US East - N. Virginia)
- **us-east-2** (US East - Ohio)
- **global** (IAM, CloudFront, Route53)

---

## Resource Summary Across All Accounts

### Compute Resources
- **Lambda Functions:** ~73 per account
- **ECS Clusters:** Varies
- **EC2 Instances:** Varies

### Database Resources
- **DynamoDB Tables:** ~53 per account
- **RDS Instances:** Varies

### Storage Resources
- **S3 Buckets:** ~36 per account (Amplify excluded)
- **EBS Volumes:** Varies
- **EFS Filesystems:** Varies

### Networking Resources
- **VPCs:** 4 per account
- **API Gateways:** 4 per account
- **Load Balancers:** Varies
- **CloudFront Distributions:** Varies

### Security Resources
- **IAM Roles:** 100 (limited query)
- **KMS Keys:** 6 per account
- **Secrets Manager:** 8 per account

### Monitoring Resources
- **CloudWatch Log Groups:** 21 per account
- **EventBridge Rules:** 4 per account
- **SNS Topics:** 1 per account
- **SQS Queues:** 1 per account

---

## Key Findings

### Resource Distribution
- All accounts show similar resource patterns, indicating shared organizational infrastructure
- Total unique resource types with data: **232**
- Resources are primarily concentrated in **us-east-1** region

### Amplify Resources
- ✅ Successfully excluded from inventory per configuration
- Focuses on core infrastructure only

### Next Steps
1. **Terraform Audit:** Run audit against this complete inventory
2. **Resource Tagging:** Review and standardize tags across accounts
3. **Cost Optimization:** Identify duplicate or unused resources
4. **Security Review:** Audit IAM roles and security group configurations
5. **Compliance:** Ensure all resources meet organizational standards

---

## Files Generated

### Master Inventory
- **File:** `aws-inventory-full.json` (1.4 MB)
- **Format:** Structured JSON with complete resource details
- **Schema:** `aws-inventory-schema.json`
- **Documentation:** `AWS-INVENTORY-README.md`

### Terraform Audit
- **Report:** `terraform-audit-report.json` (1.2 MB)
- **Import Script:** `terraform-audit-report-imports.sh` (executable)
- **Schema:** `terraform-audit-schema.json`
- **Documentation:** `TERRAFORM-AUDIT-README.md`

---

## Usage

### Query Specific Resources
```bash
# List all Lambda functions across all accounts
jq '[.accounts[].regions[].services.compute.lambda_functions[]?] | unique_by(.function_name)' aws-inventory-full.json

# Count DynamoDB tables per account
jq '[.accounts[] | {account: .account_name, tables: [.regions[].services.database.dynamodb_tables[]?] | length}]' aws-inventory-full.json

# Find S3 buckets in specific region
jq '[.accounts[].regions[] | select(.region == "us-east-1") | .services.storage.s3_buckets[]?]' aws-inventory-full.json
```

### Run Terraform Audit on Full Inventory
```bash
./scripts/terraform-audit.sh --inventory ./aws-inventory-full.json --output ./terraform-audit-full-report.json --generate-imports
```

### Schedule Daily Updates
```bash
# Add to crontab
0 2 * * * ./scripts/aws-resource-discovery.sh --output ./aws-inventory-full.json
0 3 * * * cd /home/daclab-ai/DEV/AWS-DevOps && ./scripts/terraform-audit.sh --inventory ./aws-inventory-full.json --generate-imports
```

---

**Report Location:** `/home/daclab-ai/DEV/AWS-DevOps/aws-inventory-summary.md`
