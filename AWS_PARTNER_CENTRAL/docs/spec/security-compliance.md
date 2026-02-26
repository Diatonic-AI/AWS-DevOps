# Security & Compliance Posture

## 1) Identity & Access

### 1.1 Authentication
- **External users**: Cognito User Pools with MFA enforcement (TOTP/WebAuthn)
- **Internal operators**: AWS IAM Identity Center SSO federation
- **Service-to-service**: IAM roles with short-lived credentials (STS AssumeRole)

### 1.2 Authorization Model
- **RBAC baseline**: Tenant Admin, Operator, Analyst, Viewer roles
- **ABAC extensions**: Resource tags (tenant_id, classification, environment)
- **Policy engine**: OPA-compatible policy documents stored in `policies` table

### 1.3 Least Privilege Patterns
- Connectors get scoped IAM roles per integration type
- Lambda/ECS tasks use execution roles with resource-level restrictions
- Cross-account access uses role chaining with external ID validation

## 2) Data Protection

### 2.1 Encryption
| Layer | At Rest | In Transit |
|-------|---------|------------|
| S3 Lake | KMS (CMK per tenant tier) | TLS 1.2+ |
| RDS Aurora | KMS | TLS 1.2+ (enforce SSL) |
| Redshift | KMS | TLS 1.2+ |
| Secrets Manager | AWS-managed or CMK | TLS 1.2+ |
| EventBridge | N/A | TLS 1.2+ |

### 2.2 Key Management
- **KMS key hierarchy**:
  - `lake-key`: Data lake encryption
  - `db-key`: Operational database encryption
  - `warehouse-key`: Analytics warehouse encryption
  - `secrets-key`: Secrets Manager encryption
- **Key rotation**: Automatic annual rotation enabled
- **Cross-account**: No cross-account key sharing (tenant isolation)

### 2.3 Data Classification
| Classification | Description | Controls |
|----------------|-------------|----------|
| PUBLIC | Marketing materials | No restrictions |
| INTERNAL | Business metrics | Tenant isolation |
| CONFIDENTIAL | PII, credentials | Encryption + audit + redaction |
| RESTRICTED | Partner Central secrets | HSM-backed keys |

## 3) Network Security

### 3.1 VPC Architecture
- Private subnets for compute (no public IPs)
- NAT Gateway for outbound
- VPC endpoints for AWS services (S3, Secrets Manager, EventBridge, etc.)
- Security groups: deny-all default, explicit allow rules

### 3.2 API Security
- API Gateway with WAF (rate limiting, geo-blocking, OWASP rules)
- mTLS for service mesh (optional)
- VPC Link for private integrations

## 4) Audit & Logging

### 4.1 Audit Log Requirements
Every write action records:
- `actor_user_id`: Who performed the action
- `action`: What was done (CRUD operation)
- `target_type` + `target_id`: What was affected
- `ticket_id`: Approval/change ticket reference (when applicable)
- `metadata_json`: Additional context (IP, user agent, request ID)

### 4.2 Log Retention
| Log Type | Retention | Storage |
|----------|-----------|---------|
| Application logs | 90 days hot, 1 year archive | CloudWatch + S3 |
| Audit logs | 7 years | S3 Glacier |
| Access logs | 1 year | S3 |
| VPC Flow logs | 30 days | CloudWatch |

### 4.3 Monitoring
- CloudWatch alarms for security events
- GuardDuty enabled (threat detection)
- Config Rules for compliance drift
- Security Hub aggregation

## 5) Compliance Readiness

### 5.1 SOC 2 Type II Controls
| Control Category | Implementation |
|-----------------|----------------|
| CC6.1 Logical Access | Cognito + IAM + RBAC |
| CC6.6 System Boundaries | VPC + Security Groups + WAF |
| CC6.7 Encryption | KMS + TLS |
| CC7.2 Monitoring | CloudWatch + GuardDuty |
| CC8.1 Change Management | Approval gates + audit logs |

### 5.2 GDPR Considerations
- Data subject access requests: Export API endpoint
- Right to erasure: Tenant data purge workflow
- Data minimization: PII redaction in analytics layer
- Processing records: Audit log retention

## 6) Incident Response

### 6.1 Detection
- CloudWatch anomaly detection
- GuardDuty findings → EventBridge → PagerDuty/Slack
- Custom alerts for Partner Central API errors

### 6.2 Response Runbooks
- See `docs/runbooks/incident-response.md`
- Playbooks for: credential leak, data breach, API abuse, cost spike

### 6.3 Recovery
- RTO: 4 hours (non-production), 1 hour (production)
- RPO: 1 hour (database), 24 hours (analytics)
- Backup verification: Weekly restore tests
