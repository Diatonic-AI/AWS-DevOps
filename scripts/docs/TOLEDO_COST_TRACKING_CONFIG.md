# Toledo Consulting - Cost Tracking Configuration

## 🎯 Overview

The Toledo Consulting partner dashboard has been configured with cost and usage tracking specifically for **Minute Man Press** and **Steve Heaney Investment Hub** related companies and resources.

## 📊 Cost Tracking Features

### Monitored Companies
- **Minute Man Press** (variations: `minute-man-press`, `minuteman-press`)
- **Steve Heaney Investment Hub** (variations: `steve-heaney-investment`, `steve-heaney-investment-hub`, `investment-hub`)

### Dashboard Components Added

#### 1. Monthly Cost Card
- **Location**: Top status cards (4th card)
- **Display**: Total monthly cost for tracked companies
- **Updates**: Real-time with dashboard refresh

#### 2. Company Cost Chart
- **Location**: Charts section (3rd chart)
- **Type**: Bar chart showing daily costs over 30 days
- **Granularity**: Daily cost breakdown

#### 3. Company Cost Breakdown Section
- **Location**: Above resources table
- **Features**:
  - Individual company cost cards
  - Top 5 service breakdown
  - 30-day cost totals

### API Endpoints

#### `/costs` - Cost and Usage Data
```
GET /costs
```

**Response Structure**:
```json
{
  "period": {
    "start": "2026-01-01",
    "end": "2026-01-31"
  },
  "companies": ["minute-man-press", "steve-heaney-investment", "..."],
  "summary": {
    "totalCost": 123.45,
    "dailyCosts": [
      {"date": "2026-01-01", "cost": 4.12},
      {"date": "2026-01-02", "cost": 5.23}
    ],
    "serviceBreakdown": {
      "Amazon EC2": 45.67,
      "Amazon S3": 12.34
    },
    "companyBreakdown": {
      "minute-man-press": 78.90,
      "steve-heaney-investment": 44.55
    }
  }
}
```

## 🏷️ Required Resource Tags

For resources to appear in cost tracking, they must be tagged with:

### Primary Tags (at least one required):
- `Company=minute-man-press` OR
- `Company=steve-heaney-investment` OR  
- `Company=steve-heaney-investment-hub` OR
- `Project=minute-man-press` OR
- `Project=steve-heaney-investment`

### Partner Tag (always required):
- `Partner=toledo-consulting`

## 🔧 AWS Permissions

The Lambda function now has Cost Explorer permissions:

```json
{
  "Effect": "Allow", 
  "Action": [
    "ce:GetCostAndUsage",
    "ce:GetDimensionValues", 
    "ce:GetReservationCoverage",
    "ce:GetReservationPurchaseRecommendation",
    "ce:GetReservationUtilization",
    "ce:GetUsageReport",
    "ce:ListCostCategoryDefinitions"
  ],
  "Resource": "*"
}
```

## 📋 Implementation Details

### Cost Data Filtering
The system uses AWS Cost Explorer API with the following filters:

1. **Tag-based Filtering**: Resources with company-specific tags
2. **Time Range**: Rolling 30-day window  
3. **Granularity**: Daily cost breakdown
4. **Grouping**: By Company tag, Project tag, and Service

### Data Processing
- **Daily Aggregation**: Costs summed by day for trend analysis
- **Company Attribution**: Smart matching of tag values to company names
- **Service Breakdown**: Top 5 services by cost for operational insights

## 🚀 Deployment

The cost tracking functionality is included in the main dashboard deployment:

```bash
./deploy-toledo-dashboard.sh
```

This will deploy the updated Lambda function with cost tracking capabilities.

## 📊 Usage Instructions

### For Toledo Consulting Team:
1. **Tag Resources**: Ensure all Minute Man Press and Steve Heaney Investment Hub resources are properly tagged
2. **Monitor Dashboard**: Cost data appears in the main dashboard
3. **Review Monthly**: Use the cost breakdown to understand spending patterns

### Sample Resource Tagging:
```bash
# Tag an EC2 instance for Minute Man Press
aws ec2 create-tags \
  --resources i-1234567890abcdef0 \
  --tags Key=Partner,Value=toledo-consulting \
         Key=Company,Value=minute-man-press \
         Key=Project,Value=printing-infrastructure

# Tag an S3 bucket for Steve Heaney Investment Hub  
aws s3api put-bucket-tagging \
  --bucket investment-hub-data \
  --tagging 'TagSet=[
    {Key=Partner,Value=toledo-consulting},
    {Key=Company,Value=steve-heaney-investment-hub},
    {Key=Project,Value=investment-platform}
  ]'
```

## ⚠️ Important Notes

### Cost Data Availability
- **Delay**: Cost data has a 24-48 hour delay from AWS
- **Accuracy**: Daily costs are estimates; monthly billing provides final amounts
- **Currency**: All costs displayed in USD

### Troubleshooting
- **No Cost Data**: Verify resources are tagged correctly and have been running >24 hours
- **Missing Companies**: Check tag values match the monitored company list
- **Permission Errors**: Ensure Cost Explorer permissions are active

### Cost Control
- Monitor the dashboard regularly for unexpected cost increases
- Set up AWS Budgets for automated alerts on the tagged resources
- Review service breakdown to identify optimization opportunities

---

**Last Updated**: January 24, 2026  
**Configuration**: Cost tracking for Minute Man Press and Steve Heaney Investment Hub  
**Scope**: Toledo Consulting partner dashboard

*This configuration enables Toledo Consulting to monitor and track AWS costs specifically for their two key client companies while maintaining security boundaries.*