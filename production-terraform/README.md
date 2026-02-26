# Production Terraform (Minimal Set)

Purpose: Manage only the resources required for the live Diatonic AI site:
- Amplify (or CloudFront + S3) hosting layer for web app
- Cognito User Pool / Identity Pool for auth
- API Gateway + Lambda(s) serving production APIs
- DynamoDB tables actually used by production
- Secrets Manager entries (Stripe keys, etc.)
- Route53 records for primary domain + SSL cert via ACM
- CloudWatch log groups for the above

Excluded: dev/test resources, experimental modules, unused lambdas, duplicated API gateways, partner event buses unless required.

## Next Steps
1. Import existing prod resources: use `terraform import` commands (will be generated).
2. Remove corresponding blocks from legacy folders once stable.
3. Enforce tagging: Environment=prod, ManagedBy=terraform, Project=ai-nexus.

## Structure (proposed)
- providers.tf
- variables.tf
- main-network.tf (if VPC needed) or skip if all serverless
- amplify-or-distribution.tf
- auth-cognito.tf
- api.tf (API Gateway + Lambda modules)
- data-storage.tf (DynamoDB, S3)
- dns-route53.tf
- secrets.tf
- outputs.tf

## Import Planning
Run the audit script then map ARN -> resource blocks here.
