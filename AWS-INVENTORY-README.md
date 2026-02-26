# AWS Resource Inventory System

## Overview

This system provides comprehensive automated discovery of all AWS resources across your organization, excluding Amplify frontend/backend deployments. The inventory is stored as a structured JSON file (`aws-inventory.json`) that serves as a source of truth for your AWS infrastructure.

## Quick Start

```bash
# Run discovery for current account across us-east-1 and us-east-2
./scripts/aws-resource-discovery.sh

# Run for specific account
./scripts/aws-resource-discovery.sh --account 313476888312

# Run for all organization accounts
./scripts/aws-resource-discovery.sh --regions us-east-1,us-east-2

# Include Amplify resources
./scripts/aws-resource-discovery.sh --include-amplify

# Verbose output for debugging
./scripts/aws-resource-discovery.sh --verbose
```

## Discovered Services

### Compute
- **EC2 Instances**: Running instances with state, type, and launch time
- **ECS Clusters**: Container orchestration clusters with running task counts
- **ECS Services**: Service definitions with desired/running counts
- **Lambda Functions**: Serverless functions with runtime, memory, timeout, and ARNs

### Storage
- **S3 Buckets**: Object storage with region assignment and Amplify detection
- **EBS Volumes**: Block storage (placeholder for future implementation)
- **EFS Filesystems**: File storage (placeholder for future implementation)

### Database
- **DynamoDB Tables**: NoSQL tables with item counts, size, and status
- **RDS Instances**: Relational databases with engine, version, and allocated storage
- **RDS Clusters**: Aurora clusters (placeholder for future implementation)

### Networking
- **VPCs**: Virtual private clouds with CIDR blocks and default status
- **Subnets**: Subnet configuration (placeholder for future implementation)
- **Security Groups**: Firewall rules (placeholder for future implementation)
- **Load Balancers**: ALB, NLB, and Classic ELBs with DNS names
- **API Gateways**: REST and HTTP APIs with IDs and endpoints
- **CloudFront Distributions**: CDN distributions with domain names and status

### Containers
- **ECR Repositories**: Docker image repositories with URIs and tag mutability

### Security
- **IAM Roles**: Identity roles (limited to 100 most recent)
- **IAM Policies**: Access policies (placeholder for future implementation)
- **Secrets Manager**: Stored secrets with last accessed dates
- **KMS Keys**: Encryption keys with state and manager type (limited to 50)

### DNS
- **Route53 Hosted Zones**: DNS zones with record counts
- **Route53 Records**: DNS records (placeholder for future implementation)

### Authentication
- **Cognito User Pools**: User authentication pools with creation dates
- **Cognito Identity Pools**: Federated identity (placeholder for future implementation)

### Monitoring
- **CloudWatch Alarms**: Metric alarms (placeholder for future implementation)
- **CloudWatch Log Groups**: Log aggregation with retention policies (limited to 100)
- **EventBridge Rules**: Event-driven automation rules with schedules

### Messaging
- **SNS Topics**: Publish/subscribe notification topics
- **SQS Queues**: Message queuing with queue URLs

### Frontend (Optional)
- **Amplify Apps**: Frontend hosting applications (excluded by default)

## Inventory JSON Structure

The `aws-inventory.json` file follows this structure:

```json
{
  "metadata": {
    "generated_at": "2026-01-24T16:27:00Z",
    "organization_id": "o-eyf5fcwrr3",
    "master_account_id": "313476888312",
    "regions_scanned": ["us-east-1", "us-east-2"],
    "accounts_scanned": [...],
    "version": "1.0.0",
    "scan_duration_seconds": 294
  },
  "summary": {
    "total_resources": 123,
    "resources_by_service": {...},
    "resources_by_region": {...},
    "resources_by_account": {...}
  },
  "accounts": [
    {
      "account_id": "313476888312",
      "account_name": "DiatonicAI",
      "regions": [
        {
          "region": "us-east-1",
          "services": {
            "compute": {...},
            "storage": {...},
            ...
          }
        }
      ]
    }
  ]
}
```

## Filtering and Exclusions

### Amplify Resources

By default, **Amplify resources are excluded** from the inventory to focus on core infrastructure:

- Amplify apps are not discovered (unless `--include-amplify` is specified)
- S3 buckets with `amplify:app_id` tags are filtered out
- This prevents frontend deployment artifacts from cluttering the infrastructure inventory

To include Amplify resources:
```bash
./scripts/aws-resource-discovery.sh --include-amplify
```

### Resource Limits

Some services have built-in limits to prevent excessive output:

- **IAM Roles**: Limited to first 100 roles
- **KMS Keys**: Limited to first 50 keys
- **CloudWatch Log Groups**: Limited to first 100 groups

These limits can be adjusted in the script if needed.

## Scheduling

### Cron Setup

To run daily at 2 AM:

```bash
# Edit crontab
crontab -e

# Add this line
0 2 * * * /home/daclab-ai/DEV/AWS-DevOps/scripts/aws-resource-discovery.sh --output /home/daclab-ai/DEV/AWS-DevOps/aws-inventory.json
```

### Systemd Timer (Alternative)

Create `/etc/systemd/system/aws-inventory.timer`:

```ini
[Unit]
Description=AWS Resource Discovery Timer

[Timer]
OnCalendar=daily
OnCalendar=02:00
Persistent=true

[Install]
WantedBy=timers.target
```

Create `/etc/systemd/system/aws-inventory.service`:

```ini
[Unit]
Description=AWS Resource Discovery Service

[Service]
Type=oneshot
User=daclab-ai
WorkingDirectory=/home/daclab-ai/DEV/AWS-DevOps
ExecStart=/home/daclab-ai/DEV/AWS-DevOps/scripts/aws-resource-discovery.sh
```

Enable and start:
```bash
sudo systemctl enable aws-inventory.timer
sudo systemctl start aws-inventory.timer
```

## Querying the Inventory

### Count Resources by Type

```bash
jq '[.accounts[].regions[].services | to_entries[] | .value | to_entries[] | select(.value | length > 0) | {type: .key, count: (.value | length)}] | group_by(.type) | map({type: .[0].type, total: (map(.count) | add)})' aws-inventory.json
```

### List All Lambda Functions

```bash
jq '[.accounts[].regions[] | select(.region != "global") | .services.compute.lambda_functions[]] | unique_by(.function_name)' aws-inventory.json
```

### Find Resources in Specific Region

```bash
jq '.accounts[].regions[] | select(.region == "us-east-1")' aws-inventory.json
```

### Get S3 Buckets Excluding Amplify

```bash
jq '[.accounts[].regions[].services.storage.s3_buckets[] | select(.is_amplify == false)]' aws-inventory.json
```

## Cross-Account Discovery

The script automatically discovers all accounts in your AWS Organization. To run cross-account discovery:

1. Ensure your IAM user/role has `organizations:ListAccounts` permission
2. Ensure you have read access to resources in all accounts (typically via OrganizationAccountAccessRole)
3. Run without the `--account` flag:

```bash
./scripts/aws-resource-discovery.sh
```

## Error Handling

The script includes robust error handling:

- Missing services return empty arrays `[]` instead of failing
- API errors are silently caught and logged in verbose mode
- Null values from AWS CLI are handled gracefully
- Large JSON structures use temp files to avoid "Argument list too long" errors

## Performance

Typical scan times:

- **Single account, single region**: ~90-120 seconds
- **Single account, two regions + global**: ~180-300 seconds
- **All 9 organization accounts**: ~20-30 minutes

## Output Files

- **Primary**: `aws-inventory.json` - The main inventory file
- **Temporary**: `/tmp/aws_discovery_*.json` - Temporary files (auto-cleaned)
- **Schema**: `aws-inventory-schema.json` - JSON schema definition

## Schema Validation

To validate the inventory against the schema:

```bash
# Install ajv-cli if needed
npm install -g ajv-cli

# Validate
ajv validate -s aws-inventory-schema.json -d aws-inventory.json
```

## Extending the Script

To add a new service:

1. Create a discovery function in the script:
```bash
discover_my_service() {
    local region=$1
    aws my-service list-resources --region "$region" \
        --query '...' --output json | jq '...' || echo "[]"
}
```

2. Add the call in `scan_region()` function:
```bash
"my_service_category": {
    "my_resources": $(discover_my_service "$region")
}
```

3. Test with verbose mode:
```bash
./scripts/aws-resource-discovery.sh --verbose
```

## Troubleshooting

### Permission Errors

Ensure your AWS credentials have these permissions:
- `ec2:Describe*`
- `lambda:List*`, `lambda:Get*`
- `dynamodb:List*`, `dynamodb:Describe*`
- `s3:ListAllMyBuckets`, `s3:GetBucketLocation`, `s3:GetBucketTagging`
- `iam:List*`, `iam:Get*`
- `organizations:List*`, `organizations:Describe*`
- And read permissions for all other discovered services

### Slow Performance

- Use `--regions us-east-1` to scan fewer regions
- Use `--account ACCOUNT_ID` to scan specific accounts
- Consider excluding services you don't need

### Invalid JSON Output

- Check `/tmp/claude/*/tasks/*.output` for error logs
- Run with `--verbose` to see detailed progress
- Validate with: `jq -e . aws-inventory.json`

## Support

For issues or questions:
- Check logs in verbose mode
- Review the script at `scripts/aws-resource-discovery.sh`
- Validate JSON structure with `jq`
- Check AWS CLI version: `aws --version` (requires 2.x)

## Version History

- **1.0.0** (2026-01-24): Initial release
  - Support for 20+ AWS services
  - Cross-account and cross-region discovery
  - Amplify resource filtering
  - Robust error handling
  - JSON schema validation
