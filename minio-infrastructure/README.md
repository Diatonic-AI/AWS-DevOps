# MinIO Standalone Infrastructure with S3 Integration

This project provides a completely independent MinIO system integrated with dedicated AWS S3 buckets, separate from the main AWS-DevOps CloudFormation infrastructure.

## 🏗️ Architecture Overview

### Components
- **Local MinIO Server**: Running in LXD container at `10.10.10.16:9000`
- **AWS S3 Backend**: Dedicated S3 buckets for data persistence
- **Bidirectional Sync**: Real-time synchronization between local MinIO and S3
- **Independent Infrastructure**: Separate from existing AWS-DevOps CloudFormation

### Data Flow
```
[Applications] → [Local MinIO (LXD)] ⟷ [AWS S3 Buckets]
     ↓                   ↓                    ↓
Local API Access    Local Storage      Cloud Persistence
```

## 📦 Infrastructure Components

### AWS Resources (via Terraform)
- **S3 Buckets**:
  - `minio-standalone-dev-minio-data-10b24c3f` - Primary data storage
  - `minio-standalone-dev-minio-backups-10b24c3f` - Backup storage
  - `minio-standalone-dev-minio-uploads-10b24c3f` - Temporary uploads
  - `minio-standalone-dev-minio-logs-10b24c3f` - Access and audit logs

- **IAM Resources**:
  - User: `minio-standalone-dev-minio-user`
  - Policy: `minio-standalone-dev-minio-s3-policy`
  - Access Keys: Configured in MinIO container

- **Monitoring**:
  - CloudWatch Log Group: `/aws/minio/minio-standalone-dev`
  - S3 Metrics and Lifecycle Policies

### Local Components (LXD Container)
- **MinIO Server**: Latest version with S3-compatible API
- **MinIO Client (mc)**: For management and synchronization
- **Sync Scripts**: Bidirectional sync between local and S3
- **Service Management**: systemd integration

## 🚀 Quick Start

### 1. Deploy AWS Infrastructure
```bash
cd /home/daclab-ai/dev/AWS-DevOps/minio-infrastructure/terraform
terraform init
terraform plan
terraform apply
```

### 2. Access MinIO Services
- **API Endpoint**: `http://10.10.10.16:9000`
- **Web Console**: `http://10.10.10.16:9001`
- **Credentials**: `minioadmin` / `minioadmin123`

### 3. Sync Operations
```bash
# Sync local to S3
lxc exec minio -- /usr/local/bin/sync-to-s3.sh

# Sync S3 to local
lxc exec minio -- /usr/local/bin/sync-from-s3.sh
```

## 🔧 Configuration Details

### Terraform Configuration
Located in `terraform/` directory:
- `main.tf` - Main infrastructure configuration
- `variables.tf` - Configurable parameters
- `outputs.tf` - Important resource information
- `terraform.tfvars` - Environment-specific values

### MinIO Configuration
Located in LXD container `/etc/default/minio`:
```bash
MINIO_VOLUMES=/data
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin123
MINIO_CONSOLE_ADDRESS=:9001
MINIO_BROWSER=on

# AWS S3 credentials for external integration
AWS_ACCESS_KEY_ID=AKIAUR7FNW34J2ECXGP4
AWS_SECRET_ACCESS_KEY=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
AWS_REGION=us-east-2
```

## 📊 Monitoring and Management

### Health Checks
```bash
# MinIO health
curl http://10.10.10.16:9000/minio/health/live

# Container status
lxc list minio

# Service status
lxc exec minio -- systemctl status minio
```

### Bucket Operations
```bash
# List local buckets
lxc exec minio -- mc ls local/

# List S3 buckets
lxc exec minio -- mc ls s3aws/

# Copy file to local MinIO
lxc exec minio -- mc cp /path/to/file local/data/

# Verify sync to S3
aws s3 ls s3://minio-standalone-dev-minio-data-10b24c3f/data/
```

## 🔒 Security Configuration

### IAM Policy
The MinIO IAM user has specific permissions limited to the dedicated S3 buckets:
- List and get bucket information
- Put, get, and delete objects
- Manage multipart uploads
- No access to other AWS resources

### Network Security
- MinIO server accessible only within LXD network (10.10.10.0/24)
- S3 communication over HTTPS
- IAM user follows least privilege principle

### Data Encryption
- S3 server-side encryption enabled (AES256)
- Data in transit encrypted via HTTPS
- Local storage on encrypted LXD container filesystem

## 🔄 Sync Architecture

### Bidirectional Synchronization
- **Local → S3**: `/usr/local/bin/sync-to-s3.sh`
- **S3 → Local**: `/usr/local/bin/sync-from-s3.sh`
- **Conflict Resolution**: Last write wins (overwrites enabled)
- **Sync Frequency**: Manual trigger (can be automated via cron)

### Data Consistency
- Uses MinIO client `mc mirror` command
- Supports incremental synchronization
- Maintains file metadata and timestamps
- Error handling for failed transfers

## 🛠️ Maintenance Operations

### Backup and Recovery
```bash
# Create snapshot of MinIO container
lxc snapshot minio minio-backup-$(date +%Y%m%d)

# Export container for disaster recovery
lxc export minio minio-export-$(date +%Y%m%d).tar.gz

# Backup Terraform state
cp terraform/terraform.tfstate terraform/terraform.tfstate.backup
```

### Updates and Upgrades
```bash
# Update MinIO server
lxc exec minio -- bash -c '
  systemctl stop minio
  wget -O /usr/local/bin/minio https://dl.min.io/server/minio/release/linux-amd64/minio
  chmod +x /usr/local/bin/minio
  systemctl start minio
'

# Update MinIO client
lxc exec minio -- bash -c '
  wget -O /usr/local/bin/mc https://dl.min.io/client/mc/release/linux-amd64/mc
  chmod +x /usr/local/bin/mc
'
```

### Cost Optimization
- S3 Intelligent Tiering enabled for automatic cost optimization
- Lifecycle policies transition data to cheaper storage classes
- Incomplete multipart uploads cleaned up after 7 days
- Old versions in versioned buckets automatically expired

## 📈 Scaling and Performance

### Current Limits
- Single MinIO instance (suitable for development/testing)
- Local storage: 250 GiB available
- Network throughput limited by LXD container resources

### Scaling Options
- Deploy additional MinIO containers for distributed setup
- Increase LXD container resources (CPU, memory, storage)
- Implement load balancing for multiple MinIO instances
- Use MinIO federation for multi-site deployments

## 🚨 Troubleshooting

### Common Issues

#### MinIO Service Won't Start
```bash
# Check logs
lxc exec minio -- journalctl -u minio -n 50

# Verify configuration
lxc exec minio -- cat /etc/default/minio

# Check disk space
lxc exec minio -- df -h /data
```

#### Sync Failures
```bash
# Test S3 connectivity
lxc exec minio -- mc ls s3aws/

# Check AWS credentials
aws sts get-caller-identity

# Verify bucket permissions
aws s3 ls s3://minio-standalone-dev-minio-data-10b24c3f/
```

#### Performance Issues
```bash
# Monitor container resources
lxc info minio

# Check MinIO metrics
curl http://10.10.10.16:9000/minio/v2/metrics/cluster

# Analyze network throughput
lxc exec minio -- iftop -i eth0
```

## 📋 Testing and Validation

### Functional Tests
```bash
# Test file upload to local MinIO
echo "test content" | lxc exec minio -- mc pipe local/data/test.txt

# Test sync to S3
lxc exec minio -- /usr/local/bin/sync-to-s3.sh

# Verify file in S3
aws s3 ls s3://minio-standalone-dev-minio-data-10b24c3f/data/

# Test reverse sync
aws s3 cp - s3://minio-standalone-dev-minio-data-10b24c3f/data/reverse-test.txt <<< "reverse sync test"
lxc exec minio -- /usr/local/bin/sync-from-s3.sh
lxc exec minio -- mc cat local/data/reverse-test.txt
```

### Load Testing
```bash
# Generate test files
for i in {1..100}; do
  echo "Test file $i content" | lxc exec minio -- mc pipe local/data/test-file-$i.txt
done

# Measure sync performance
time lxc exec minio -- /usr/local/bin/sync-to-s3.sh
```

## 📚 Additional Resources

- [MinIO Documentation](https://min.io/docs/minio/linux/index.html)
- [MinIO Client Guide](https://min.io/docs/minio/linux/reference/minio-mc.html)
- [AWS S3 API Reference](https://docs.aws.amazon.com/s3/latest/API/Welcome.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## 📞 Support and Contact

For issues related to this MinIO standalone infrastructure:
1. Check troubleshooting guide above
2. Review MinIO and AWS S3 logs
3. Verify Terraform state consistency
4. Test individual components (MinIO, S3, sync scripts)

---

**Last Updated**: 2025-09-07  
**Version**: 1.0  
**Infrastructure Version**: Terraform managed  
**MinIO Version**: RELEASE.2025-07-23T15-54-02Z
