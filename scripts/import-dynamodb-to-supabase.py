#!/usr/bin/env python3 -u
"""
DynamoDB to Supabase Bulk Import Script

This script imports data from DynamoDB tables to Supabase via the Edge Function webhook.
Supports pagination, batch processing, and progress tracking.

Usage:
    python3 import-dynamodb-to-supabase.py --table firespring-backdoor-visitors-dev --region us-east-1
    python3 import-dynamodb-to-supabase.py --all-firespring --region us-east-1
    python3 import-dynamodb-to-supabase.py --all-leads --region us-east-2
"""

import argparse
import boto3
import json
import requests
import time
import sys
from decimal import Decimal
from typing import Dict, List, Any, Optional
from concurrent.futures import ThreadPoolExecutor, as_completed

# Configuration
SUPABASE_WEBHOOK_URL = "https://jpcdwbkeivtmweoacbsh.functions.supabase.co/mmp-toledo-sync"
SUPABASE_ANON_KEY = "sb_publishable_d40P6CytE7W2RW01I1lzfg_fQTfJkTW"

# Batch settings
BATCH_SIZE = 25  # Records per webhook call
MAX_CONCURRENT_REQUESTS = 5
RETRY_ATTEMPTS = 3
RETRY_DELAY = 2

# Table mappings
TABLE_MAPPINGS = {
    # Firespring tables (us-east-1)
    'firespring-backdoor-actions-dev': 'firespring_actions',
    'firespring-backdoor-extraction-jobs-dev': 'firespring_extraction_jobs',
    'firespring-backdoor-network-state-dev': 'firespring_network_state',
    'firespring-backdoor-searches-dev': 'firespring_searches',
    'firespring-backdoor-segments-dev': 'firespring_segments',
    'firespring-backdoor-traffic-sources-dev': 'firespring_traffic_sources',
    'firespring-backdoor-visitors-dev': 'firespring_visitors',
    # Lead tables (us-east-2)
    'Lead-sqiqbtbugvfabolqwdt4rz3dla-NONE': 'mmp_toledo_leads',
    'Lead-h6a66mxndnhc7h3o4kldil67oa-NONE': 'mmp_toledo_leads',
    'Lead-sfyatimxznhd3nybi6mcbg5ipq-NONE': 'mmp_toledo_leads',
    'Lead-x5u6a7nejrcfbjj6qld46eamai-NONE': 'mmp_toledo_leads',
    'Lead-xllvnlnajffmznanpuyhq3pl6i-NONE': 'mmp_toledo_leads',
    'toledo-consulting-dashboard-data': 'toledo_dashboard',
}

FIRESPRING_TABLES = [
    'firespring-backdoor-actions-dev',
    'firespring-backdoor-extraction-jobs-dev',
    'firespring-backdoor-network-state-dev',
    'firespring-backdoor-searches-dev',
    'firespring-backdoor-segments-dev',
    'firespring-backdoor-traffic-sources-dev',
    'firespring-backdoor-visitors-dev',
]

LEAD_TABLES = [
    'Lead-sqiqbtbugvfabolqwdt4rz3dla-NONE',
    'Lead-h6a66mxndnhc7h3o4kldil67oa-NONE',
    'Lead-sfyatimxznhd3nybi6mcbg5ipq-NONE',
    'Lead-x5u6a7nejrcfbjj6qld46eamai-NONE',
    'Lead-xllvnlnajffmznanpuyhq3pl6i-NONE',
]


class DecimalEncoder(json.JSONEncoder):
    """Handle Decimal types from DynamoDB"""
    def default(self, obj):
        if isinstance(obj, Decimal):
            if obj % 1 == 0:
                return int(obj)
            return float(obj)
        return super().default(obj)


def convert_dynamodb_item(item: Dict) -> Dict:
    """Convert DynamoDB item format to plain Python dict"""
    result = {}
    for key, value in item.items():
        result[key] = convert_dynamodb_value(value)
    return result


def convert_dynamodb_value(value: Any) -> Any:
    """Convert a single DynamoDB value"""
    if isinstance(value, dict):
        if 'S' in value:
            return value['S']
        elif 'N' in value:
            num = Decimal(value['N'])
            return int(num) if num % 1 == 0 else float(num)
        elif 'B' in value:
            return value['B']
        elif 'SS' in value:
            return value['SS']
        elif 'NS' in value:
            return [float(Decimal(n)) for n in value['NS']]
        elif 'BS' in value:
            return value['BS']
        elif 'M' in value:
            return convert_dynamodb_item(value['M'])
        elif 'L' in value:
            return [convert_dynamodb_value(item) for item in value['L']]
        elif 'NULL' in value:
            return None
        elif 'BOOL' in value:
            return value['BOOL']
        else:
            # Plain dict (already converted by boto3)
            return {k: convert_dynamodb_value(v) for k, v in value.items()}
    elif isinstance(value, list):
        return [convert_dynamodb_value(item) for item in value]
    elif isinstance(value, Decimal):
        return int(value) if value % 1 == 0 else float(value)
    return value


def send_to_supabase(supabase_table: str, records: List[Dict], dry_run: bool = False) -> Dict:
    """Send batch of records to Supabase Edge Function"""
    if dry_run:
        return {'success': True, 'dry_run': True, 'count': len(records)}

    results = {'success': 0, 'failed': 0, 'errors': []}

    for record in records:
        payload = {
            'table': supabase_table,
            'action': 'UPSERT',
            'data': record
        }

        for attempt in range(RETRY_ATTEMPTS):
            try:
                response = requests.post(
                    SUPABASE_WEBHOOK_URL,
                    headers={
                        'Content-Type': 'application/json',
                        'Authorization': f'Bearer {SUPABASE_ANON_KEY}'
                    },
                    json=payload,
                    timeout=30
                )

                if response.status_code == 200:
                    results['success'] += 1
                    break
                else:
                    if attempt == RETRY_ATTEMPTS - 1:
                        results['failed'] += 1
                        results['errors'].append({
                            'record_id': record.get('id', 'unknown'),
                            'status': response.status_code,
                            'error': response.text[:200]
                        })
                    time.sleep(RETRY_DELAY)
            except Exception as e:
                if attempt == RETRY_ATTEMPTS - 1:
                    results['failed'] += 1
                    results['errors'].append({
                        'record_id': record.get('id', 'unknown'),
                        'error': str(e)
                    })
                time.sleep(RETRY_DELAY)

    return results


def scan_dynamodb_table(table_name: str, region: str) -> List[Dict]:
    """Scan entire DynamoDB table with pagination"""
    dynamodb = boto3.client('dynamodb', region_name=region)
    items = []
    last_evaluated_key = None
    page = 0

    print(f"  Scanning {table_name}...")

    while True:
        scan_kwargs = {'TableName': table_name}
        if last_evaluated_key:
            scan_kwargs['ExclusiveStartKey'] = last_evaluated_key

        response = dynamodb.scan(**scan_kwargs)
        page_items = response.get('Items', [])
        items.extend(page_items)
        page += 1

        print(f"    Page {page}: {len(page_items)} items (total: {len(items)})")

        last_evaluated_key = response.get('LastEvaluatedKey')
        if not last_evaluated_key:
            break

    return items


def import_table(table_name: str, region: str, dry_run: bool = False) -> Dict:
    """Import a single DynamoDB table to Supabase"""
    supabase_table = TABLE_MAPPINGS.get(table_name)
    if not supabase_table:
        supabase_table = table_name.replace('-', '_').lower()
        print(f"  Warning: No mapping for {table_name}, using {supabase_table}")

    print(f"\n{'[DRY RUN] ' if dry_run else ''}Importing {table_name} -> {supabase_table}")

    # Scan DynamoDB
    raw_items = scan_dynamodb_table(table_name, region)
    if not raw_items:
        print(f"  No items found in {table_name}")
        return {'table': table_name, 'total': 0, 'success': 0, 'failed': 0}

    # Convert items
    print(f"  Converting {len(raw_items)} items...")
    converted_items = []
    for item in raw_items:
        converted = convert_dynamodb_item(item)
        # Add source metadata
        converted['_source_table'] = table_name
        converted['_import_timestamp'] = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
        converted_items.append(converted)

    # Send to Supabase in batches
    print(f"  Sending to Supabase in batches of {BATCH_SIZE}...")
    total_success = 0
    total_failed = 0
    all_errors = []

    for i in range(0, len(converted_items), BATCH_SIZE):
        batch = converted_items[i:i + BATCH_SIZE]
        batch_num = (i // BATCH_SIZE) + 1
        total_batches = (len(converted_items) + BATCH_SIZE - 1) // BATCH_SIZE

        result = send_to_supabase(supabase_table, batch, dry_run)
        total_success += result.get('success', 0)
        total_failed += result.get('failed', 0)
        all_errors.extend(result.get('errors', []))

        print(f"    Batch {batch_num}/{total_batches}: {result.get('success', 0)} ok, {result.get('failed', 0)} failed")

        # Rate limiting
        time.sleep(0.1)

    summary = {
        'table': table_name,
        'supabase_table': supabase_table,
        'total': len(converted_items),
        'success': total_success,
        'failed': total_failed,
        'errors': all_errors[:10]  # Limit error details
    }

    print(f"  Complete: {total_success}/{len(converted_items)} imported successfully")
    if total_failed > 0:
        print(f"  {total_failed} records failed")

    return summary


def main():
    global BATCH_SIZE

    parser = argparse.ArgumentParser(description='Import DynamoDB tables to Supabase')
    parser.add_argument('--table', type=str, help='Specific table to import')
    parser.add_argument('--region', type=str, default='us-east-1', help='AWS region')
    parser.add_argument('--all-firespring', action='store_true', help='Import all Firespring tables')
    parser.add_argument('--all-leads', action='store_true', help='Import all Lead tables')
    parser.add_argument('--dry-run', action='store_true', help='Simulate without actually importing')
    parser.add_argument('--batch-size', type=int, default=25, help='Records per batch')

    args = parser.parse_args()
    BATCH_SIZE = args.batch_size

    tables_to_import = []

    if args.all_firespring:
        tables_to_import = FIRESPRING_TABLES
        args.region = 'us-east-1'
    elif args.all_leads:
        tables_to_import = LEAD_TABLES
        args.region = 'us-east-2'
    elif args.table:
        tables_to_import = [args.table]
    else:
        print("Error: Specify --table, --all-firespring, or --all-leads")
        sys.exit(1)

    print(f"{'='*60}")
    print(f"DynamoDB to Supabase Import")
    print(f"{'='*60}")
    print(f"Region: {args.region}")
    print(f"Tables: {len(tables_to_import)}")
    print(f"Dry Run: {args.dry_run}")
    print(f"Batch Size: {BATCH_SIZE}")
    print(f"{'='*60}")

    results = []
    for table in tables_to_import:
        try:
            result = import_table(table, args.region, args.dry_run)
            results.append(result)
        except Exception as e:
            print(f"  Error importing {table}: {e}")
            results.append({
                'table': table,
                'error': str(e),
                'total': 0,
                'success': 0,
                'failed': 0
            })

    # Print summary
    print(f"\n{'='*60}")
    print("IMPORT SUMMARY")
    print(f"{'='*60}")
    total_records = sum(r.get('total', 0) for r in results)
    total_success = sum(r.get('success', 0) for r in results)
    total_failed = sum(r.get('failed', 0) for r in results)

    for r in results:
        status = 'OK' if r.get('failed', 0) == 0 else 'PARTIAL'
        if r.get('error'):
            status = 'ERROR'
        print(f"  {r['table']}: {r.get('success', 0)}/{r.get('total', 0)} [{status}]")

    print(f"\nTotal: {total_success}/{total_records} records imported")
    if total_failed > 0:
        print(f"Failed: {total_failed} records")

    return 0 if total_failed == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
