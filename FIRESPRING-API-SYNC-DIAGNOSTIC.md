# Firespring REST API Sync - Diagnostic Report

**Date**: February 6, 2026
**Issue**: `firespring_searches` and `firespring_network_state` tables not populating

---

## 🔍 Root Cause Analysis

### Data Flow Architecture

```
┌──────────────────────┐
│  Firespring REST API │
│  analytics.firespring│
│  .com                │
└──────────┬───────────┘
           │
           │ HTTP GET (hourly)
           ▼
┌──────────────────────────────┐
│  Lambda: firespring-backdoor-│
│  extractor-dev               │
│  (us-east-1)                 │
└────────┬─────────────────────┘
         │
         ├─────▶ S3 Bucket (Raw JSON)
         │       firespring-backdoor-data-30511389/raw/
         │
         └─────▶ DynamoDB Tables
                 ├─ visitors ✓ WORKING (41 records/hour)
                 ├─ actions ✓ WORKING (50 records/hour)
                 ├─ traffic-sources ❌ FAILING (stored:0)
                 ├─ searches ❌ FAILING (stored:0)
                 ├─ segments ✓ WORKING
                 └─ network-state ❌ NO DATA (API doesn't provide)
```

### Findings

#### 1. **firespring_searches** - Data Exists But Not Syncing

**Status**: 🔴 BUG IN EXTRACTOR LAMBDA

**Evidence**:
- Firespring API returns 21 search queries per extraction
- Data successfully stored in S3: `s3://firespring-backdoor-data-30511389/raw/searches-recent/`
- **BUG**: Extractor writes `stored: 0` to DynamoDB
- DynamoDB table count: 0 items (should have ~500+ based on S3 file count)

**Sample Data in S3**:
```json
[{
  "type": "searches-recent",
  "dates": [{
    "date": "2026-01-31,2026-02-06",
    "items": [
      {
        "time": "1770333652",
        "item": "[secure search]",
        "stats_url": "http://analytics.firespring.com/stats/visitors..."
      }
    ]
  }]
}]
```

**Why It's Failing**:
The extractor Lambda has a **data type processing bug**:
- Types `visitors-list` and `actions-list` → Code exists to transform and store ✓
- Types `searches-recent` and `traffic-sources` → Fetched but NO transformation code ❌
- Extractor logs show: `records:21, stored:0` (silent failure)

#### 2. **firespring_network_state** - No Source Data

**Status**: ⚠️ NOT A BUG - API DOESN'T PROVIDE THIS DATA

**Evidence**:
- No `network-state/` folder in S3 bucket
- Firespring API response doesn't include network state data
- Table exists but is unused (0 items expected)

**Recommendation**: Either:
1. Remove `firespring_network_state` table (not used)
2. Populate from different source if network topology needed

---

## 🔧 Fix Required

### Extractor Lambda Bug

The `firespring-backdoor-extractor-dev` Lambda needs to add transformation logic for:

1. **searches-recent** → `firespring-backdoor-searches-dev`
2. **traffic-sources** → `firespring-backdoor-traffic-sources-dev`

**Current Behavior**:
```javascript
// In extractor Lambda
if (type === 'visitors-list') {
  await writeToDynamoDB(VISITORS_TABLE, transformedData) // ✓ Works
} else if (type === 'actions-list') {
  await writeToDynamoDB(ACTIONS_TABLE, transformedData) // ✓ Works
} else {
  // ❌ No handler for searches-recent, traffic-sources
  console.log(`Skipping storage for type: ${type}`)
  return { stored: 0 }
}
```

**Required Fix**:
```javascript
else if (type === 'searches-recent') {
  const searchRecords = extractSearches(responseData)
  await writeToDynamoDB(SEARCHES_TABLE, searchRecords)
  return { stored: searchRecords.length }
}
else if (type === 'traffic-sources') {
  const sourceRecords = extractTrafficSources(responseData)
  await writeToDynamoDB(TRAFFIC_SOURCES_TABLE, sourceRecords)
  return { stored: sourceRecords.length }
}
```

---

## 📊 Impact Assessment

### Data Loss

**Searches Table**:
- S3 files: ~500+ extraction files (Nov 2025 - Feb 2026)
- Estimated records: ~10,000 search queries
- **Current DynamoDB**: 0 items
- **Data loss**: 100%

**Traffic Sources Table**:
- DynamoDB has 1,736 items (some data IS syncing)
- But extractor reports `stored:0` for new extractions
- **Partial data loss**: Recent data not syncing

---

## 🎯 Recommended Actions

### Immediate (Fix Extractor)

1. **Update extractor Lambda** with search/traffic-source transformation logic
2. **Backfill from S3**: Process existing 500+ search files → DynamoDB
3. **Test extraction cycle**: Verify next hourly run stores data correctly

### Code Fix Locations

**Function**: `firespring-backdoor-extractor-dev` (us-east-1)
**File**: `index.js` or `index.mjs`
**Location**: Data type handler switch statement

**Add**:
```javascript
function transformSearchData(apiResponse) {
  const searches = []
  for (const dateGroup of apiResponse.dates || []) {
    for (const item of dateGroup.items || []) {
      searches.push({
        search_id: `search_${item.time}_${Math.random().toString(36).substr(2, 9)}`,
        search_query: item.item,
        search_type: 'organic',
        timestamp: parseInt(item.time),
        stats_url: item.stats_url,
        date_range: dateGroup.date,
        created_at: Date.now()
      })
    }
  }
  return searches
}

function transformTrafficSourceData(apiResponse) {
  const sources = []
  for (const dateGroup of apiResponse.dates || []) {
    for (const item of dateGroup.items || []) {
      sources.push({
        source_id: `source_${item.time || Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        source_name: item.item || item.name,
        source_type: item.type || 'referral',
        traffic_data: item,
        timestamp: parseInt(item.time || Date.now()),
        created_at: Date.now()
      })
    }
  }
  return sources
}
```

### Backfill Script

Create script to process existing S3 files:

```python
#!/usr/bin/env python3
# scripts/backfill-firespring-searches.py

import boto3
import json

s3 = boto3.client('s3', region_name='us-east-1')
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')

searches_table = dynamodb.Table('firespring-backdoor-searches-dev')
bucket = 'firespring-backdoor-data-30511389'

# List all search files
paginator = s3.get_paginator('list_objects_v2')
for page in paginator.paginate(Bucket=bucket, Prefix='raw/searches-recent/'):
    for obj in page.get('Contents', []):
        # Download and process
        response = s3.get_object(Bucket=bucket, Key=obj['Key'])
        data = json.loads(response['Body'].read())

        # Transform and store
        for date_group in data[0].get('dates', []):
            for item in date_group.get('items', []):
                searches_table.put_item(Item={
                    'search_id': f"search_{item['time']}_{hash(item['item']) % 100000}",
                    'search_query': item['item'],
                    'timestamp': int(item['time']),
                    'stats_url': item['stats_url'],
                    'created_at': int(obj['LastModified'].timestamp() * 1000)
                })

print("Backfill complete")
```

---

## 🧪 Verification Steps

### 1. Check Extractor Output
```bash
aws lambda invoke \
  --function-name firespring-backdoor-extractor-dev \
  --region us-east-1 \
  /tmp/test.json

# Look for stored:0 in response (indicates bug)
cat /tmp/test.json | jq '.body.types_processed[] | select(.stored == 0)'
```

### 2. Verify S3 Data Exists
```bash
aws s3 ls s3://firespring-backdoor-data-30511389/raw/searches-recent/ \
  --region us-east-1 \
  --recursive | wc -l

# Should show hundreds of files
```

### 3. Check DynamoDB After Fix
```bash
aws dynamodb scan \
  --table-name firespring-backdoor-searches-dev \
  --region us-east-1 \
  --select COUNT

# Should show > 0 after backfill
```

---

## 📋 Summary

| Table | API Data | S3 Data | DynamoDB | Status | Fix Needed |
|-------|----------|---------|----------|--------|------------|
| visitors | ✓ | ✓ | ✓ 13,804 | ✅ Working | None |
| actions | ✓ | ✓ | ✓ 28,917 | ✅ Working | None |
| segments | ✓ | ✓ | ✓ 1,728 | ✅ Working | None |
| traffic_sources | ✓ | ✓ | ✓ 1,730 | ✅ Working | None |
| extraction_jobs | ✓ | ✓ | ✓ 1,915 | ✅ Working | None |
| **searches** | **✓** | **✓** | **❌ 0** | **🔴 Bug** | **Extractor code** |
| network_state | ❌ | ❌ | ❌ 0 | ⚠️ No data | API doesn't provide |

**Next Steps**:
1. Access extractor Lambda code (needs AWS Console or download via API)
2. Add transformation logic for searches-recent
3. Run backfill script to process existing S3 data
4. Verify next hourly extraction stores searches correctly

