# Stripe Integration Service

This service integrates Stripe's billing API with AWS cost management, enabling automated usage-based billing and real-time notifications.

## Overview

The Stripe integration provides:

- **Cost Monitoring**: Daily checks of AWS costs via Cost Explorer API
- **Automated Billing**: Creates Stripe invoices when budget thresholds are exceeded
- **Webhook Processing**: Handles Stripe events for payment confirmations
- **Notifications**: SNS alerts for billing events and budget alerts
- **Data Persistence**: Stores billing and subscription data in DynamoDB

### Production Features

- **Data Protection**: DynamoDB Point-in-Time Recovery enabled
- **Monitoring Dashboard**: Comprehensive CloudWatch dashboard
- **Budget Alerts**: Configurable thresholds with SNS notifications
- **Secure Configuration**: SSM Parameter Store for secrets
- **Resource Tagging**: Full Diatonic-AI Global Org compliance

## Architecture

```
AWS Cost Explorer ──► Lambda (Cost Monitor) ──► Stripe API
       │                       │
       │                       ▼
       │               DynamoDB (Billing Records)
       │                       │
       ▼                       ▼
CloudWatch Alarms ──► SNS Notifications
       ▲
       │
Stripe Webhooks ──► Lambda (Billing Handler) ──► DynamoDB
```

## Components

### Lambda Functions

- **Cost Monitor**: Queries AWS costs, checks budgets, creates Stripe invoices
- **Billing Handler**: Processes Stripe webhooks, updates records, sends notifications

### Data Storage

- **Billing Table**: Stores invoice and payment records
- **Subscriptions Table**: Tracks customer subscriptions

### Infrastructure

- **API Gateway**: Exposes webhook endpoint for Stripe
- **EventBridge**: Schedules daily cost monitoring
- **CloudWatch**: Monitors budgets and alarms
- **SNS**: Notification system for alerts

## Cost Estimate

**Total Monthly Cost**: ~$1.00 (development environment, low usage)

See [cost-analysis.md](cost-analysis.md) for detailed breakdown.

## Setup

### Prerequisites

1. Stripe account with API keys
2. AWS account with Cost Explorer enabled
3. Budgets configured in AWS
4. Proper IAM permissions for CloudFormation deployment

### Environment Variables

Set the following in AWS Systems Manager Parameter Store:

- `/stripe/secret-key`: Your Stripe secret key
- `/stripe/webhook-secret`: Stripe webhook endpoint secret

### Deployment

#### For Development/Testing:
```bash
cd scripts
./deploy.sh dev us-east-1
```

#### For Small Production:
```bash
cd scripts
./deploy-prod.sh us-east-1
```

The production script includes:
- Pre-deployment validation checks
- SSM parameter verification
- Production-specific configuration
- Enhanced monitoring dashboard
- DynamoDB point-in-time recovery
- Conservative budget threshold ($1000)

#### Manual Deployment:

1. Package Lambda functions:
   ```bash
   cd lambda/cost-monitor
   npm install
   zip -r cost-monitor.zip .

   cd ../billing-handler
   npm install
   zip -r billing-handler.zip .
   ```

2. Deploy CloudFormation stack:
   ```bash
   aws cloudformation deploy \
     --template-file infrastructure.yaml \
     --stack-name stripe-integration-prod \
     --parameter-overrides \
       Environment=prod \
       ClientOrganization=Diatonic-AI \
       BillingProject=global-org-tools \
       OrganizationalUnit=ToolsAndResources \
       BillingAllocationID=STRIPE-INT-001 \
       Owner=PlatformTeam \
       CostCenter=Engineering \
       Project=StripeIntegration \
       BudgetThreshold=1000 \
     --capabilities CAPABILITY_IAM
   ```

3. Configure Stripe webhook:
   - Go to Stripe Dashboard > Webhooks
   - Add endpoint: `[API Gateway URL]/webhook`
   - Select events: `invoice.payment_*`, `customer.subscription.*`

## Configuration

### Budget Thresholds

Set `BUDGET_THRESHOLD` parameter (default: $800) to trigger billing when exceeded.

### Notifications

Subscribe email addresses to the SNS topic for billing alerts.

## API Reference

### Cost Monitor Lambda

**Trigger**: EventBridge (daily at 6 AM UTC)

**Environment Variables**:
- `STRIPE_SECRET_KEY`: Stripe API key
- `BUDGET_THRESHOLD`: Cost threshold for billing
- `SNS_TOPIC_ARN`: Notification topic
- `BILLING_TABLE_NAME`: DynamoDB table name

### Billing Handler Lambda

**Trigger**: API Gateway (Stripe webhooks)

**Environment Variables**:
- `STRIPE_SECRET_KEY`: Stripe API key
- `STRIPE_WEBHOOK_SECRET`: Webhook signature secret
- `SNS_TOPIC_ARN`: Notification topic
- `BILLING_TABLE_NAME`: DynamoDB table name
- `SUBSCRIPTIONS_TABLE_NAME`: DynamoDB table name

## Monitoring

### CloudWatch Metrics

- Lambda invocation counts and durations
- DynamoDB read/write capacity
- API Gateway request counts

### Logs

All Lambda functions log to CloudWatch Logs with structured JSON.

### Alerts

- Budget threshold exceeded
- Payment succeeded/failed
- Subscription changes

## Security

- API keys stored in SSM Parameter Store
- Webhook signature verification
- IAM roles with least privilege
- VPC deployment (optional)

## Testing

### Unit Tests

```bash
npm test
```

### Integration Tests

Use Stripe CLI for webhook testing:

```bash
stripe listen --forward-to [API Gateway URL]/webhook
stripe trigger invoice.payment_succeeded
```

## Troubleshooting

### Common Issues

1. **Webhook signature verification fails**
   - Check `STRIPE_WEBHOOK_SECRET` parameter
   - Ensure webhook endpoint secret is correct

2. **Cost Explorer API access denied**
   - Enable Cost Explorer in AWS account
   - Verify IAM permissions

3. **Stripe API errors**
   - Check API key validity
   - Review Stripe dashboard for rate limits

### Logs

Check CloudWatch Logs for detailed error information:

```bash
aws logs tail /aws/lambda/stripe-cost-monitor-dev --follow
```

## Contributing

1. Follow existing code patterns
2. Add unit tests for new features
3. Update documentation
4. Test in dev environment before production

## License

Internal use only.