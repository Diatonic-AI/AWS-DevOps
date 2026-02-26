# Toledo Consulting - Partner Dashboard Deployment

## 🎯 Overview

Complete AWS infrastructure deployment for Toledo Consulting's custom partner dashboard. This provides a secure, tag-based dashboard system that integrates with their existing IAM permissions and resource groups.

## 📋 What's Included

### Infrastructure Components
- **S3 Bucket**: Hosts dashboard frontend assets with versioning and encryption
- **DynamoDB Table**: Stores dashboard configurations and partner-specific data
- **Lambda Function**: Backend API for metrics, resources, and dashboard operations
- **API Gateway**: RESTful endpoints with CORS support
- **CloudWatch Dashboard**: Partner-specific metrics and monitoring
- **CloudFront Distribution**: Global content delivery for dashboard performance
- **IAM Roles**: Least-privilege access for all dashboard services

### Security Features  
- **Tag-based Access Control**: All resources tagged with `Partner=toledo-consulting`
- **Resource Isolation**: Partner can only access their tagged resources
- **Encrypted Storage**: S3 encryption and secure data handling
- **CORS Protection**: Secure cross-origin resource sharing

### Dashboard Features
- **Real-time Metrics**: API usage, resource status, performance monitoring
- **Resource Management**: View and manage partner-tagged AWS resources
- **Interactive Charts**: Visual representation of metrics and utilization
- **Responsive Design**: Works on desktop and mobile devices

## 🚀 Quick Start Deployment

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform >= 1.0 installed
- Bash shell environment

### 1. Deploy Infrastructure

```bash
# Make sure you're in the project root
cd /home/daclab-ai/DEV/AWS-DevOps

# Run the deployment script
./deploy-toledo-dashboard.sh
```

The script will:
1. ✅ Check prerequisites (AWS CLI, Terraform, credentials)
2. 🔧 Initialize Terraform configuration
3. ✅ Validate Terraform syntax and formatting
4. 📋 Create deployment plan
5. 🚀 Deploy infrastructure (after confirmation)
6. 🌐 Upload frontend to S3 and configure API endpoints
7. 🧪 Test deployment and display access URLs

### 2. Access Information

After successful deployment:

**Partner Dashboard URL**: `https://[cloudfront-domain]/`  
**API Gateway URL**: `https://[api-id].execute-api.us-east-2.amazonaws.com/prod/`  
**CloudWatch Dashboard**: Available in AWS Console

**Partner Login Credentials**:
- Console: `https://313476888312.signin.aws.amazon.com/console`
- Username: `toledo-consulting-admin`
- Password: `X*d^9LdlwU&Ahh$e` ✅ **READY TO USE** (reset completed)

## 📊 Dashboard Features

### Main Dashboard
- **System Status**: Overall health and availability
- **Active Resources**: Count of partner-tagged resources
- **API Requests**: Real-time API usage metrics
- **Performance**: System performance indicators

### Charts & Visualizations
- **API Usage (24h)**: Time-series graph of API requests
- **Resource Utilization**: Pie chart showing active/stopped/pending resources

### Resource Management
- **EC2 Instances**: View status, type, and manage instances
- **RDS Databases**: Monitor database status and performance
- **Tagged Resources**: Automatic discovery via `Partner=toledo-consulting` tag

## 🔧 API Endpoints

The dashboard API provides the following endpoints:

### Health Check
```
GET /health
```
Returns system health status and service availability.

### Metrics
```
GET /metrics
```
Returns partner-specific CloudWatch metrics and API usage statistics.

### Resources
```
GET /resources
```
Lists all AWS resources tagged with `Partner=toledo-consulting`.

### Dashboard Configuration
```
GET /dashboard
POST /dashboard
```
Get or update dashboard configuration settings.

### Configuration
```
GET /config
```
Returns API configuration and version information.

## 🏷️ Tagging Strategy

All dashboard resources are automatically tagged with:

```yaml
Partner: toledo-consulting
CompanyType: contractor
Services: ai-consulting
Certification: veteran-owned
Environment: prod
Project: partner-dashboard
ManagedBy: terraform
CreatedBy: diatonic-ai
```

**For partner resource access**: Any AWS resource tagged with `Partner=toledo-consulting` will automatically appear in the dashboard and be manageable by the partner user.

## 🔐 Security Model

### IAM Permissions
The partner user (`toledo-consulting-admin`) has:
- **Read Access**: CloudWatch metrics, EC2/RDS/S3 status, resource metadata
- **Limited Management**: Start/stop tagged EC2/RDS instances, invoke tagged Lambda functions
- **Resource Group Access**: Full access to partner-specific resource group

### Resource Isolation
- All permissions are constrained by resource tags
- Principal tag conditions ensure only partner users can access partner resources
- No access to resources belonging to other partners or the main organization

### Network Security
- CloudFront distribution with HTTPS enforcement
- API Gateway with CORS restrictions
- Lambda functions in VPC (if required)

## 📁 File Structure

```
/home/daclab-ai/DEV/AWS-DevOps/
├── infrastructure/terraform/
│   ├── modules/partner-dashboard/
│   │   ├── main.tf                    # Main infrastructure
│   │   ├── variables.tf               # Input variables
│   │   ├── outputs.tf                 # Output values
│   │   ├── dashboard-api.zip          # Lambda deployment package
│   │   └── lambda/
│   │       ├── index.js               # Lambda function code
│   │       └── package.json           # Dependencies
│   └── environments/prod/
│       └── toledo-consulting-dashboard.tf  # Production deployment
├── dashboard-frontend/
│   └── index.html                     # React dashboard frontend
├── deploy-toledo-dashboard.sh         # Deployment script
├── toledo-consulting-*.json           # Configuration files
├── toledo-consulting-*.md             # Documentation
└── TOLEDO_DASHBOARD_README.md         # This file
```

## 🔄 Updates & Maintenance

### Updating Infrastructure
```bash
# Make changes to Terraform files
# Re-run deployment script
./deploy-toledo-dashboard.sh
```

### Updating Frontend
```bash
# Update dashboard-frontend/index.html
# Re-run deployment to upload changes
./deploy-toledo-dashboard.sh
```

### Adding New Partners
The infrastructure is designed to be reusable. To add a new partner:

1. Create new module instantiation in `environments/prod/`
2. Update partner-specific variables
3. Deploy using the same script pattern

### Monitoring
- CloudWatch Dashboard: Partner-specific metrics
- CloudWatch Logs: Lambda function execution logs
- CloudWatch Alarms: Can be configured for resource thresholds

## 🧪 Testing

### Manual Testing
```bash
# Test API endpoints
curl -X GET https://[api-url]/health
curl -X GET https://[api-url]/resources
curl -X GET https://[api-url]/metrics

# Test dashboard frontend
# Open dashboard URL in browser
```

### Resource Validation
```bash
# Verify resource tagging
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Partner,Values=toledo-consulting

# Check partner permissions
aws iam simulate-principal-policy \
  --principal-arn arn:aws:iam::313476888312:user/toledo-consulting-admin \
  --action-names ec2:DescribeInstances \
  --resource-arns "*"
```

## 🚨 Troubleshooting

### Common Issues

**API Gateway 403 Errors**
- Check Lambda permissions and IAM role policies
- Verify CORS configuration

**Dashboard Shows No Resources**
- Ensure resources are tagged with `Partner=toledo-consulting`
- Check IAM permissions for resource discovery

**CloudFront Distribution Not Accessible**
- Allow 10-15 minutes for propagation
- Check S3 bucket policy and origin access identity

**Lambda Function Errors**
- Check CloudWatch logs: `/aws/lambda/toledo-consulting-dashboard-api`
- Verify environment variables and DynamoDB permissions

### Debug Commands
```bash
# Check Terraform state
terraform show

# Verify AWS resources
aws lambda list-functions --query 'Functions[?contains(FunctionName, `toledo-consulting`)]'
aws s3 ls | grep toledo-consulting
aws dynamodb list-tables | grep toledo-consulting

# Check API Gateway
aws apigatewayv2 get-apis --query 'Items[?contains(Name, `toledo-consulting`)]'
```

## 📞 Support

For technical support or questions:
- Check CloudWatch logs for error details
- Review IAM permissions and resource tagging
- Validate Terraform configuration and state
- Test API endpoints individually

---

**Deployed**: January 23, 2026  
**Version**: 1.0.0  
**Partner**: Toledo Consulting & Contracting LLC  
**Environment**: Production (us-east-2)

---

*This dashboard provides Toledo Consulting with secure, self-service access to their AWS resources while maintaining proper isolation and security boundaries.*