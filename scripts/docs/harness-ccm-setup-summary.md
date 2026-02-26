# Harness CCM Setup Summary

## AWS Infrastructure Setup ✅ COMPLETED

### Cost and Usage Reports (CUR)
- **Report Name**: `harness-ccm-cur-report`
- **S3 Bucket**: `harness-ccm-cur-313476888312`
- **S3 Prefix**: `cost-usage-reports`
- **Region**: `us-east-2`
- **Format**: CSV with GZIP compression
- **Time Unit**: Hourly
- **Include Resource IDs**: Yes ✅
- **Refresh Automatically**: Yes ✅

### IAM Cross-Account Role
- **Role ARN**: `arn:aws:iam::313476888312:role/HarnessCCMRole`
- **External ID**: `harness-ccm-external-id`
- **CloudFormation Stack**: `harness-ccm-setup`

### Permissions Included
- ✅ Cost Visibility (required)
- ✅ Resource Inventory Management  
- ✅ AutoStopping Optimization
- ✅ Cloud Governance
- ✅ Commitment Orchestration
- ✅ S3 bucket access for CUR data

## Manual Steps Required

### 1. Enable EC2 Recommendations (AWS Console)
🔴 **REQUIRED**: Go to AWS Cost Explorer > Preferences and enable:
- "Receive Amazon EC2 resource recommendations"
- "Recommendations for linked accounts"

**Note**: This can only be done through the AWS Console, not CLI.

### 2. Create Harness Connector (Harness Console)
Use these values when creating the AWS connector in Harness:

**Step 1: Connector Overview**
- Connector Name: `aws-devops-ccm`
- AWS Account ID: `313476888312`
- AWS GovCloud: No

**Step 2: Cost and Usage Report**
- Report Name: `harness-ccm-cur-report`
- S3 Bucket Name: `harness-ccm-cur-313476888312`

**Step 3: Features to Enable**
- ✅ Cost Visibility (required)
- ✅ Resource Inventory Management
- ✅ Optimization by AutoStopping
- ✅ Cloud Governance
- ✅ Commitment Orchestration

**Step 4: Authentication**
- Cross Account Role ARN: `arn:aws:iam::313476888312:role/HarnessCCMRole`
- External ID: `harness-ccm-external-id`

## Validation Commands

```bash
# Verify CUR report exists
aws cur describe-report-definitions --region us-east-1

# Verify S3 bucket access
aws s3 ls s3://harness-ccm-cur-313476888312/

# Verify IAM role exists
aws iam get-role --role-name HarnessCCMRole

# Test role assumption (after Harness setup)
aws sts assume-role --role-arn arn:aws:iam::313476888312:role/HarnessCCMRole --role-session-name test-session --external-id harness-ccm-external-id
```

## Expected Timeline

- **CUR Data Generation**: 6-8 hours for first report
- **Harness Data Availability**: 24 hours after CUR data is available
- **EC2 Recommendations**: Up to 24 hours after enabling in console

## Troubleshooting

### Common Issues
1. **CUR file not found**: Wait 6-8 hours for first report generation
2. **Permission denied**: Verify External ID matches exactly
3. **No recommendations**: Enable in Cost Explorer preferences and wait 24 hours

### Support Resources
- Harness Documentation: https://docs.harness.io/category/ccm
- AWS Cost Explorer: https://aws.amazon.com/aws-cost-management/aws-cost-explorer/
- CloudFormation Stack: Can be updated if permissions need modification

## Next Steps

1. ✅ AWS CLI configuration complete
2. 🔴 Enable EC2 recommendations in AWS Console
3. 🔴 Create Harness connector using values above
4. 🔴 Set up Harness MCP server tools
5. 🔴 Configure automated reporting and cost optimization