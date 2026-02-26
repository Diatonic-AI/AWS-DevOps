# NAT Gateway Cost Optimization - Urgent Fix Required

**Status**: 🔴 Not functioning - $30/month waste
**Priority**: HIGH
**Potential Savings**: $29.70/month ($356/year)

---

## 🚨 Current Problem

### Cost Optimization Intended Design

```
EventBridge (every 5 min)
  ↓
Lambda: firespring-backdoor-network-manager-dev
  ├─ Check last extraction job timestamp
  ├─ If idle > 5 minutes:
  │   ├─ Delete NAT Gateway
  │   ├─ Write state to firespring_network_state table
  │   └─ Update route table (remove NAT route)
  └─ Before extraction:
      ├─ Create NAT Gateway
      ├─ Update route table (add NAT route)
      └─ Write state change

Expected Savings: $32.40/month → $2.70/month = $29.70 saved
```

### Actual Behavior

```
❌ Lambda returns: nat_gateway: null (can't find NAT)
❌ NAT Gateway: Always running (State: available)
❌ Table writes: 0 records
❌ Cost: $32.40/month (no savings)

NAT Gateway ID: nat-09f31157ff1ea1bcf
VPC: vpc-04864ab584b8852f8
Subnet: subnet-02cf902556e45ba4c
```

---

## 🔍 Root Cause Analysis

### Why Lambda Can't Find NAT Gateway

The Lambda searches for NAT Gateway but returns `null`. Possible causes:

1. **IAM Permissions Missing**
   - Lambda needs `ec2:DescribeNatGateways` permission
   - May not have permission to read NAT Gateway details

2. **Search Logic Bug**
   - Lambda may be searching by wrong filter
   - Code might expect specific tags that don't exist

3. **Region Mismatch**
   - Lambda in us-east-1 ✓
   - NAT Gateway in us-east-1 ✓
   - Should not be an issue

### Lambda Response Analysis

```json
{
  "nat_gateway": null,           // ❌ Can't find NAT
  "last_activity": null,         // ❌ Can't check jobs
  "idle_timeout": 300,           // ✓ Config loaded
  "config": {
    "vpc_id": "vpc-04864ab584b8852f8",    // ✓ Correct
    "public_subnet_id": "subnet-02cf902556e45ba4c",  // ✓ Matches NAT
    "private_route_table_id": "rtb-0358deac9dde530c7"  // ✓ Valid
  }
}
```

**Conclusion**: Lambda has correct VPC config but EC2 API call failing (likely permissions)

---

## 🔧 Fix Options

### Option A: Fix Lambda Permissions (Recommended)

**Required IAM Permissions**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeNatGateways",
        "ec2:CreateNatGateway",
        "ec2:DeleteNatGateway",
        "ec2:DescribeRouteTables",
        "ec2:CreateRoute",
        "ec2:DeleteRoute",
        "ec2:ReplaceRoute",
        "dynamodb:PutItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:GetItem"
      ],
      "Resource": "*"
    }
  ]
}
```

**Steps to Fix**:
```bash
# 1. Get Lambda role name
ROLE_ARN=$(aws lambda get-function-configuration \
  --function-name firespring-backdoor-network-manager-dev \
  --region us-east-1 \
  --query "Role" --output text)

ROLE_NAME=$(basename $ROLE_ARN)

# 2. Attach EC2 permissions
aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name NAT-Gateway-Lifecycle-Management \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeNatGateways",
        "ec2:CreateNatGateway",
        "ec2:DeleteNatGateway",
        "ec2:DescribeRouteTables",
        "ec2:CreateRoute",
        "ec2:DeleteRoute"
      ],
      "Resource": "*"
    }]
  }'

# 3. Test Lambda again
aws lambda invoke \
  --function-name firespring-backdoor-network-manager-dev \
  --region us-east-1 \
  /tmp/test.json

# Should now see: "nat_gateway": {"id": "nat-09f31157ff1ea1bcf", ...}
```

### Option B: Disable Cost Optimization (Quick Fix)

**If you don't want to fix it**:
```bash
# Disable the EventBridge rule
aws events disable-rule \
  --name firespring-backdoor-network-idle-check \
  --region us-east-1

echo "NAT Gateway will remain active 24/7"
echo "Cost: $32.40/month (predictable, no risk)"
```

### Option C: Manual NAT Management (Alternative)

**Stop NAT when not needed**:
```bash
# Manually delete NAT Gateway (saves money immediately)
aws ec2 delete-nat-gateway \
  --nat-gateway-id nat-09f31157ff1ea1bcf \
  --region us-east-1

# Before running extractions, recreate it:
aws ec2 create-nat-gateway \
  --subnet-id subnet-02cf902556e45ba4c \
  --allocation-id <ELASTIC_IP_ID> \
  --region us-east-1
```

---

## 🧪 Testing the Fix

### 1. Verify Lambda Can Find NAT

```bash
aws lambda invoke \
  --function-name firespring-backdoor-network-manager-dev \
  --region us-east-1 \
  /tmp/test.json

# Expected output (after fix):
{
  "nat_gateway": {
    "id": "nat-09f31157ff1ea1bcf",
    "state": "available",
    "subnet_id": "subnet-02cf902556e45ba4c"
  },
  "last_activity": 1770371843900,
  "idle_duration": 125,
  "action": "none"  // or "stopping_nat" if idle > 300s
}
```

### 2. Verify State Tracking

```sql
-- Check network_state table (should have records after fix)
SELECT * FROM firespring_network_state ORDER BY updated_at DESC LIMIT 5;

-- Expected:
-- node_id | nat_gateway_id | state | idle_since | cost_savings_usd
-- nat-xxx | nat-09f... | available | null | 0.00
```

### 3. Verify Cost Savings

```bash
# After 24 hours of fixed operation, check NAT usage
aws ec2 describe-nat-gateways \
  --nat-gateway-ids nat-09f31157ff1ea1bcf \
  --region us-east-1 \
  --query "NatGateways[0].State"

# Should be "deleted" most of the time, "available" during extractions
```

---

## 📊 Expected Behavior After Fix

### Hourly Extraction Cycle

```
00:00 - Extraction starts
00:00:01 - Network-manager creates NAT Gateway
00:05:00 - Extraction completes (5 min duration)
00:05:01 - Network-manager detects idle
00:10:01 - 5 min idle timeout reached
00:10:02 - Network-manager deletes NAT Gateway
00:10:03 - Write state: {stopped_at, cost_savings: $0.0375}

01:00 - Next extraction starts
01:00:01 - Network-manager recreates NAT Gateway
... repeat

Daily Pattern:
  - NAT active: ~2 hours (24 extractions × 5 min each)
  - NAT idle: ~22 hours
  - Daily cost: $0.09 (vs $1.08)
  - Monthly savings: $29.70
```

---

## 🎯 Immediate Actions Required

### Step 1: Check Lambda IAM Role

```bash
# Get role name
ROLE_ARN=$(aws lambda get-function-configuration \
  --function-name firespring-backdoor-network-manager-dev \
  --region us-east-1 \
  --query "Role" --output text)

echo "Role: $(basename $ROLE_ARN)"

# List current policies
aws iam list-attached-role-policies \
  --role-name "$(basename $ROLE_ARN)"

# Check if EC2 permissions exist
aws iam get-role-policy \
  --role-name "$(basename $ROLE_ARN)" \
  --policy-name NAT-Gateway-Lifecycle-Management 2>&1

# If not exists, policy needs to be added
```

### Step 2: Add Missing Permissions

```bash
# Create the policy document
cat > /tmp/nat-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "NATGatewayLifecycle",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeNatGateways",
        "ec2:CreateNatGateway",
        "ec2:DeleteNatGateway",
        "ec2:DescribeSubnets",
        "ec2:DescribeRouteTables",
        "ec2:CreateRoute",
        "ec2:DeleteRoute",
        "ec2:ReplaceRoute"
      ],
      "Resource": "*"
    },
    {
      "Sid": "StateTableAccess",
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:Query"
      ],
      "Resource": "arn:aws:dynamodb:us-east-1:*:table/firespring-backdoor-network-state-dev"
    }
  ]
}
EOF

# Attach policy
aws iam put-role-policy \
  --role-name "$(basename $ROLE_ARN)" \
  --policy-name NAT-Gateway-Lifecycle-Management \
  --policy-document file:///tmp/nat-policy.json \
  --region us-east-1
```

### Step 3: Test Fixed Lambda

```bash
# Invoke and verify NAT is found
aws lambda invoke \
  --function-name firespring-backdoor-network-manager-dev \
  --region us-east-1 \
  /tmp/test.json

cat /tmp/test.json | jq '.nat_gateway'
# Should NOT be null anymore

# Check if state is being written
aws dynamodb scan \
  --table-name firespring-backdoor-network-state-dev \
  --region us-east-1 \
  --limit 1
```

### Step 4: Monitor for 24 Hours

```sql
-- Check state changes in Supabase
SELECT
  nat_gateway_id,
  state,
  stopped_at,
  started_at,
  cost_savings_usd,
  updated_at
FROM firespring_network_state
ORDER BY updated_at DESC
LIMIT 10;

-- Calculate actual savings
SELECT
  SUM(cost_savings_usd) as total_savings,
  COUNT(*) as stop_start_cycles
FROM firespring_network_state
WHERE stopped_at IS NOT NULL;
```

---

## ⚠️ Risks of NAT Lifecycle Management

### Potential Issues

1. **Extraction Failures**
   - If NAT not ready when extraction starts
   - Network timeouts during NAT creation

2. **Race Conditions**
   - Multiple extractors starting simultaneously
   - NAT deletion while extraction in progress

3. **Increased Complexity**
   - More moving parts to monitor
   - Harder to troubleshoot failures

### Mitigation

```javascript
// In extractor Lambda - add retry logic
const ensureNATAvailable = async () => {
  for (let i = 0; i < 10; i++) {
    const nat = await checkNATGateway()
    if (nat && nat.state === 'available') {
      return true
    }
    await new Promise(r => setTimeout(r, 30000)) // Wait 30s
  }
  throw new Error('NAT Gateway not available after 5 minutes')
}

// Before extraction
await ensureNATAvailable()
await extractFirespringData()
```

---

## 💡 Alternative: Keep NAT Running (Recommended)

**Rationale**:
- **Reliability**: Extractions never fail due to NAT issues
- **Simplicity**: One less system to monitor and maintain
- **Cost**: $32/month is acceptable for guaranteed uptime
- **Time Savings**: No debugging/maintenance of lifecycle system

**Trade-off**: Pay $30/month more for peace of mind

---

## ✅ Summary & Next Steps

**Current State**:
- NAT Gateway: Running 24/7 ($32.40/month)
- Network-manager Lambda: Enabled but not functioning
- network_state table: Recreated and ready
- Issue: Lambda can't find NAT (likely IAM permissions)

**Recommended Action**:
1. **Add EC2 permissions to Lambda role** (see Step 2 above)
2. **Test Lambda can find NAT Gateway**
3. **Monitor for 24 hours** to verify lifecycle works
4. **Calculate actual savings** from state table

**Alternative**:
- Disable network-manager Lambda
- Accept $32/month NAT cost
- Focus on analytics value, not infrastructure optimization

**Your Decision Needed**:
- Fix the cost optimization? (~2 hours work, $30/month savings, some risk)
- OR keep NAT running 24/7? (no work, $32/month, zero risk)
