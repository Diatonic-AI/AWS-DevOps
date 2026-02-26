# Terraform Layout
- `envs/dev|stage|prod`: environment roots
- `modules/*`: reusable modules
- State backend: S3 + DynamoDB lock (recommended)

## Modules you get out of the box
- core-network: VPC, subnets, NAT, VPC endpoints
- security-kms: KMS keys for secrets/lake/db
- secrets: Secrets Manager baselines
- eventing: EventBridge bus + DLQs
- orchestration: Step Functions + IAM
- auth: Cognito (or Identity Center integration stubs)
- data-lake: S3 + Glue catalog + Lake Formation scaffolding
- operational-db: Aurora Postgres + parameter groups
- analytics-warehouse: Redshift Serverless baseline
- vector-search: pgvector extension strategy (DB side) or OpenSearch vector
- observability: CloudWatch + X-Ray + OTEL collector stubs
- partner-central-access: IAM policies for partnercentral APIs
- marketplace-access: IAM policies for catalog + metering + entitlement