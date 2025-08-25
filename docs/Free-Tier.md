# AWS Free Tier Services & Limits

This document provides a comprehensive overview of all AWS Free Tier offerings available to help you stay within cost limits while developing and learning AWS services.

## 🕒 Free Tier Types

AWS offers three types of free tier offerings:

1. **Always Free** - No expiration date, available to all AWS customers
2. **12 Months Free** - Available for 12 months from your AWS account creation date
3. **Free Trials** - Short-term free trials for specific services

---

## 🌟 Always Free Services

These services are available at no charge with usage limits that do not expire.

| Service | Usage Limit | Details |
|---------|-------------|---------|
| **AWS Lambda** | 1M requests/month<br>400K GB-seconds compute | Serverless compute service |
| **Amazon DynamoDB** | 25GB storage<br>25 WCU & 25 RCU | NoSQL database service |
| **Amazon CloudWatch** | 10 custom metrics<br>10 alarms<br>1M API requests | Monitoring and observability |
| **Amazon SNS** | 1M publishes<br>100K HTTP/HTTPS deliveries<br>1K email deliveries | Messaging service |
| **Amazon SQS** | 1M requests/month | Message queuing service |
| **Amazon Cognito** | 50K MAUs for user pools<br>50 MAUs for identity pools | User identity and access management |
| **Amazon API Gateway** | 1M API calls/month | API management service |
| **AWS KMS** | 20K requests/month | Key management service |
| **AWS CodeBuild** | 100 build minutes/month | Continuous integration service |
| **AWS CodeCommit** | 5 users<br>50GB storage/month<br>10K requests | Git repository service |
| **AWS CodePipeline** | 1 active pipeline/month | Continuous delivery service |
| **AWS Step Functions** | 4K state transitions/month | Workflow orchestration |
| **AWS X-Ray** | 100K traces recorded/month<br>1M traces retrieved/month | Application tracing |
| **Amazon CloudFront** | 50GB data transfer out<br>2M HTTP/HTTPS requests | Content delivery network |

---

## 📅 12 Months Free Services

These services are free for the first 12 months after creating your AWS account.

### Compute Services

| Service | Usage Limit | Details |
|---------|-------------|---------|
| **Amazon EC2** | 750 hours/month of t2.micro or t3.micro | Linux, RHEL, or SLES instances |
| **AWS Elastic Beanstalk** | No charge (pay for underlying resources) | Application deployment platform |
| **AWS Lightsail** | 750 hours of t2.nano equivalent | VPS service |

### Storage Services  

| Service | Usage Limit | Details |
|---------|-------------|---------|
| **Amazon S3** | 5GB standard storage<br>20K GET requests<br>2K PUT requests | Object storage service |
| **Amazon EBS** | 30GB of any combination of volumes | Block storage for EC2 |
| **Amazon EFS** | 5GB standard storage | Network file system |
| **Amazon Glacier** | 10GB retrievals/month | Archive storage |
| **AWS Backup** | 5GB backup storage<br>10GB warm restore | Backup service |

### Database Services

| Service | Usage Limit | Details |
|---------|-------------|---------|
| **Amazon RDS** | 750 hours/month of db.t2.micro<br>20GB storage<br>20GB backup | Relational database service |
| **Amazon Redshift** | 750 hours/month of dc2.large | Data warehouse service |
| **Amazon ElastiCache** | 750 hours/month of cache.t2.micro | In-memory caching |
| **Amazon DocumentDB** | 1M I/O requests<br>1GB storage | MongoDB-compatible database |
| **Amazon Neptune** | 750 hours/month of db.t3.medium | Graph database |

### Networking & Security

| Service | Usage Limit | Details |
|---------|-------------|---------|
| **AWS VPC** | Free (no data transfer charges within AZ) | Virtual private cloud |
| **Amazon Route 53** | 25 hosted zones for domains<br>1 billion queries/month | DNS service |
| **AWS WAF** | 1 web ACL<br>10 rules<br>1M requests | Web application firewall |
| **AWS Certificate Manager** | Public & private SSL/TLS certificates | Certificate management |
| **AWS Secrets Manager** | 30-day free trial then $0.40/secret | Secrets storage |

### Analytics & Machine Learning

| Service | Usage Limit | Details |
|---------|-------------|---------|
| **Amazon Kinesis Data Streams** | 1M PUT records<br>1M shard hours<br>1M retrieval requests | Real-time data streaming |
| **Amazon Kinesis Data Firehose** | 500K records/month up to 2GB | Data delivery service |
| **AWS Glue** | 1M objects stored<br>10 DPUs for ETL jobs | Data integration service |
| **Amazon Athena** | 1TB of data scanned/month | Serverless query service |
| **Amazon Comprehend** | 50K characters/month (each API) | Natural language processing |
| **Amazon Lex** | 10K text requests<br>5K speech requests | Chatbot service |
| **Amazon Polly** | 5M characters/month | Text-to-speech service |
| **Amazon Rekognition** | 5K images/month<br>1K minutes of video | Image and video analysis |
| **Amazon Textract** | 1K pages/month (each API) | Document text extraction |
| **Amazon Translate** | 2M characters/month | Language translation |
| **Amazon Transcribe** | 60 minutes/month | Speech-to-text service |

### Developer Tools

| Service | Usage Limit | Details |
|---------|-------------|---------|
| **AWS Cloud9** | No charge (pay for underlying EC2) | Cloud IDE |
| **AWS CodeStar** | No charge for service | Project management |
| **AWS CodeDeploy** | No charge for EC2/on-premises | Deployment automation |
| **AWS CodeArtifact** | 2GB storage/month<br>100K package requests | Package repository |

---

## 🚀 Free Trials

These services offer limited-time free trials:

| Service | Trial Period | Usage Limit | Details |
|---------|--------------|-------------|---------|
| **Amazon Inspector** | 90 days | 250 EC2 instance assessments | Security assessment |
| **Amazon Macie** | 30 days | 1GB of data processed | Data security and privacy |
| **AWS Config** | No free tier | Pay per configuration item | Configuration compliance |
| **AWS CloudTrail** | No free tier for data events | Management events always free | API logging |
| **Amazon GuardDuty** | 30 days | Full feature access | Threat detection |
| **AWS Security Hub** | 30 days | Security findings aggregation | Security posture management |
| **Amazon Detective** | 30 days | 1GB data ingestion/day | Security investigation |
| **AWS Well-Architected Tool** | Always free | Architectural reviews | Architecture guidance |

---

## ⚠️ Important Free Tier Notes

### General Limitations
- **Geographic Restrictions**: Free tier usage must occur in eligible AWS regions
- **Account Age**: 12-month free tier benefits start from account creation date
- **Usage Aggregation**: Free tier limits are calculated across all regions
- **Monitoring Required**: You are responsible for tracking your usage

### Common Gotchas
- **Data Transfer**: Most outbound data transfer beyond free limits incurs charges
- **Reserved Instances**: Cannot be used with free tier benefits  
- **Support Plans**: Only Basic Support is free
- **CloudFormation**: Free service but resources created may incur charges

### Cost Monitoring Recommendations
- Set up **AWS Budgets** with $0.01 threshold to get alerts
- Use **AWS Cost Explorer** to track daily usage
- Enable **Billing Alerts** in CloudWatch
- Review **AWS Free Tier Usage** page monthly

---

## 📊 Free Tier Usage Monitoring

### Setting Up Alerts

1. **CloudWatch Billing Alerts**:
   ```bash
   aws cloudwatch put-metric-alarm --alarm-name "FreeTierExceeded" \
     --alarm-description "Alert when estimated charges exceed free tier" \
     --metric-name EstimatedCharges --namespace AWS/Billing \
     --statistic Maximum --period 86400 --threshold 1.00 \
     --comparison-operator GreaterThanThreshold
   ```

2. **AWS Budget Example**:
   ```bash
   aws budgets create-budget --account-id YOUR_ACCOUNT_ID \
     --budget '{"BudgetName":"FreeTierBudget","TimeUnit":"MONTHLY","BudgetLimit":{"Amount":"1","Unit":"USD"},"BudgetType":"COST"}'
   ```

### Useful Commands

Check your current usage:
```bash
# List EC2 instances
aws ec2 describe-instances --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name]'

# Check S3 bucket sizes
aws s3 ls --summarize --human-readable --recursive s3://your-bucket-name

# Monitor Lambda invocations
aws logs describe-metric-filters --log-group-name /aws/lambda/your-function-name

# Check RDS instances
aws rds describe-db-instances --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceClass,DBInstanceStatus]'
```

---

## 🎯 Best Practices for Staying Within Free Tier

### Resource Management
- **Tag Resources**: Use tags like `Project=FreeTier` to track free tier resources
- **Set Lifecycle Policies**: Auto-delete old S3 objects and snapshots  
- **Use Spot Instances**: For development workloads when free tier hours are exhausted
- **Monitor Continuously**: Check usage weekly, not monthly

### Service Selection
- **Choose Right Instance Types**: Always use t2.micro or t3.micro for EC2
- **Optimize Storage**: Use S3 Standard, not S3 IA or Glacier for free tier
- **Database Selection**: PostgreSQL and MySQL qualify for RDS free tier
- **Network Optimization**: Keep resources in same AZ to avoid transfer charges

### Development Practices
- **Environment Cleanup**: Regularly delete development/test resources
- **Scheduled Shutdowns**: Stop EC2 instances when not needed
- **Log Retention**: Set CloudWatch log retention to minimize storage costs
- **Function Optimization**: Optimize Lambda memory allocation and execution time

---

## 📞 Support & Resources

- **AWS Free Tier FAQ**: https://aws.amazon.com/free/free-tier-faqs/
- **AWS Calculator**: Use to estimate costs beyond free tier
- **AWS Trusted Advisor**: Available with Basic Support for cost optimization
- **AWS Forums**: Community support for free tier questions

---

*Last Updated: August 2025*  
*This document should be reviewed monthly to ensure accuracy with current AWS pricing.*
