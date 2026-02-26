#!/usr/bin/env python3 -u
"""
High-Performance Multi-Threaded DynamoDB to Supabase Import

Uses ThreadPoolExecutor for parallel batch processing to minimize import time.
Optimized for ~48K records in <5 minutes.

Usage:
    python3 fast-parallel-import.py --all-firespring --workers 20
    python3 fast-parallel-import.py --table firespring-backdoor-actions-dev --workers 20
"""

import argparse
import boto3
import json
import requests
import time
import sys
from decimal import Decimal
from typing import Dict, List, Any
from concurrent.futures import ThreadPoolExecutor, as_completed
from threading import Lock

# Configuration
SUPABASE_WEBHOOK_URL = "https://jpcdwbkeivtmweoacbsh.functions.supabase.co/mmp-toledo-sync"
SUPABASE_ANON_KEY = "sb_publishable_d40P6CytE7W2RW01I1lzfg_fQTfJkTW"

# Performance settings
DEFAULT_WORKERS = 20  # Parallel batch workers
BATCH_SIZE = 100  # Records per batch (increased from 25)
REQUEST_TIMEOUT = 60
RETRY_ATTEMPTS = 2
RETRY_DELAY = 1

# Progress tracking
progress_lock = Lock()
progress_stats = {}

FIRESPRING_TABLES = [
    'firespring-backdoor-actions-dev',
    'firespring-backdoor-visitors-dev',
    'firespring-backdoor-extraction-jobs-dev',
    'firespring-backdoor-traffic-sources-dev',
    'firespring-backdoor-segments-dev',
]

TABLE_MAPPINGS = {
    'firespring-backdoor-actions-dev': 'firespring_actions',
    'firespring-backdoor-extraction-jobs-dev': 'firespring_extraction_jobs',
    'firespring-backdoor-network-state-dev': 'firespring_network_state',
    'firespring-backdoor-searches-dev': 'firespring_searches',
    'firespring-backdoor-segments-dev': 'firespring_segments',
    'firespring-backdoor-traffic-sources-dev': 'firespring_traffic_sources',
    'firespring-backdoor-visitors-dev': 'firespring_visitors',
    'Lead-sqiqbtbugvfabolqwdt4rz3dla-NONE': 'mmp_toledo_leads',
}


class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return int(obj) if obj % 1 == 0 else float(obj)
        return super().default(obj)


def convert_dynamodb_item(item: Dict) -> Dict:
    """Convert DynamoDB item to plain dict"""
    result = {}
    for key, value in item.items():
        if isinstance(value, dict):
            if 'S' in value: result[key] = value['S']
            elif 'N' in value:
                num = Decimal(value['N'])
                result[key] = int(num) if num % 1 == 0 else float(num)
            elif 'BOOL' in value: result[key] = value['BOOL']
            elif 'NULL' in value: result[key] = None
            elif 'SS' in value: result[key] = value['SS']
            elif 'NS' in value: result[key] = [float(Decimal(n)) for n in value['NS']]
            elif 'M' in value: result[key] = convert_dynamodb_item(value['M'])
            elif 'L' in value: result[key] = [convert_dynamodb_item({'t': i})['t'] for i in value['L']]
            else: result[key] = value
        elif isinstance(value, Decimal):
            result[key] = int(value) if value % 1 == 0 else float(value)
        else:
            result[key] = value
    return result


def send_batch_to_supabase(batch_data: tuple) -> Dict:
    """Send a batch of records to Supabase (worker function)"""
    batch_num, total_batches, supabase_table, records, table_name = batch_data

    results = {'success': 0, 'failed': 0, 'batch_num': batch_num}

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
                    timeout=REQUEST_TIMEOUT
                )

                if response.status_code == 200:
                    results['success'] += 1
                    break
                elif attempt == RETRY_ATTEMPTS - 1:
                    results['failed'] += 1
            except Exception as e:
                if attempt == RETRY_ATTEMPTS - 1:
                    results['failed'] += 1
                time.sleep(RETRY_DELAY)

    # Update progress
    with progress_lock:
        key = table_name
        if key not in progress_stats:
            progress_stats[key] = {'completed': 0, 'total': total_batches, 'success': 0, 'failed': 0}
        progress_stats[key]['completed'] += 1
        progress_stats[key]['success'] += results['success']
        progress_stats[key]['failed'] += results['failed']

        # Print progress every 10 batches
        if progress_stats[key]['completed'] % 10 == 0 or progress_stats[key]['completed'] == total_batches:
            pct = (progress_stats[key]['completed'] / total_batches * 100)
            print(f"  [{table_name}] Batch {progress_stats[key]['completed']}/{total_batches} ({pct:.1f}%) - "
                  f"{progress_stats[key]['success']} ok, {progress_stats[key]['failed']} failed")

    return results


def import_table_parallel(table_name: str, region: str, num_workers: int) -> Dict:
    """Import table using parallel workers"""
    supabase_table = TABLE_MAPPINGS.get(table_name, table_name.replace('-', '_').lower())

    print(f"\n{'='*60}")
    print(f"Importing {table_name} -> {supabase_table}")
    print(f"Workers: {num_workers}, Batch Size: {BATCH_SIZE}")
    print(f"{'='*60}")

    # Scan DynamoDB
    print(f"Scanning DynamoDB table...")
    dynamodb = boto3.client('dynamodb', region_name=region)
    items = []
    last_key = None

    while True:
        scan_kwargs = {'TableName': table_name}
        if last_key:
            scan_kwargs['ExclusiveStartKey'] = last_key

        response = dynamodb.scan(**scan_kwargs)
        items.extend(response.get('Items', []))
        last_key = response.get('LastEvaluatedKey')

        if not last_key:
            break

    if not items:
        print(f"No items found")
        return {'table': table_name, 'total': 0, 'success': 0, 'failed': 0}

    print(f"Found {len(items)} items, converting...")

    # Convert items
    converted = []
    for item in items:
        conv = convert_dynamodb_item(item)
        converted.append(conv)

    # Create batches
    batches = []
    for i in range(0, len(converted), BATCH_SIZE):
        batch = converted[i:i + BATCH_SIZE]
        batch_num = (i // BATCH_SIZE) + 1
        total_batches = (len(converted) + BATCH_SIZE - 1) // BATCH_SIZE
        batches.append((batch_num, total_batches, supabase_table, batch, table_name))

    print(f"Uploading {len(batches)} batches with {num_workers} parallel workers...")

    # Process batches in parallel
    start_time = time.time()
    total_success = 0
    total_failed = 0

    with ThreadPoolExecutor(max_workers=num_workers) as executor:
        futures = [executor.submit(send_batch_to_supabase, batch) for batch in batches]

        for future in as_completed(futures):
            try:
                result = future.result()
                total_success += result['success']
                total_failed += result['failed']
            except Exception as e:
                print(f"  Batch failed: {e}")
                total_failed += BATCH_SIZE

    elapsed = time.time() - start_time
    rate = len(converted) / elapsed if elapsed > 0 else 0

    print(f"\n✓ Complete: {total_success}/{len(converted)} imported in {elapsed:.1f}s ({rate:.0f} records/sec)")
    if total_failed > 0:
        print(f"  Failed: {total_failed} records")

    return {
        'table': table_name,
        'supabase_table': supabase_table,
        'total': len(converted),
        'success': total_success,
        'failed': total_failed,
        'duration_seconds': elapsed,
        'records_per_second': rate
    }


def main():
    parser = argparse.ArgumentParser(description='Fast parallel DynamoDB to Supabase import')
    parser.add_argument('--table', type=str, help='Specific table to import')
    parser.add_argument('--region', type=str, default='us-east-1', help='AWS region')
    parser.add_argument('--all-firespring', action='store_true', help='Import all Firespring tables')
    parser.add_argument('--workers', type=int, default=DEFAULT_WORKERS, help='Number of parallel workers')

    args = parser.parse_args()

    tables_to_import = []
    if args.all_firespring:
        tables_to_import = FIRESPRING_TABLES
        args.region = 'us-east-1'
    elif args.table:
        tables_to_import = [args.table]
    else:
        print("Error: Specify --table or --all-firespring")
        sys.exit(1)

    print(f"{'='*60}")
    print(f"FAST PARALLEL IMPORT")
    print(f"Region: {args.region}")
    print(f"Tables: {len(tables_to_import)}")
    print(f"Workers: {args.workers}")
    print(f"Batch Size: {BATCH_SIZE}")
    print(f"{'='*60}")

    results = []
    overall_start = time.time()

    for table in tables_to_import:
        try:
            result = import_table_parallel(table, args.region, args.workers)
            results.append(result)
        except Exception as e:
            print(f"Error importing {table}: {e}")
            results.append({'table': table, 'error': str(e), 'total': 0, 'success': 0, 'failed': 0})

    overall_elapsed = time.time() - overall_start

    # Summary
    print(f"\n{'='*60}")
    print(f"IMPORT SUMMARY")
    print(f"{'='*60}")

    total_records = sum(r.get('total', 0) for r in results)
    total_success = sum(r.get('success', 0) for r in results)
    total_failed = sum(r.get('failed', 0) for r in results)

    for r in results:
        rate = r.get('records_per_second', 0)
        duration = r.get('duration_seconds', 0)
        print(f"  {r['table']}: {r.get('success', 0)}/{r.get('total', 0)} "
              f"in {duration:.1f}s ({rate:.0f} rec/s)")

    print(f"\n✓ Total: {total_success}/{total_records} records")
    print(f"  Duration: {overall_elapsed/60:.1f} minutes")
    print(f"  Overall rate: {total_records/overall_elapsed:.0f} records/sec")
    if total_failed > 0:
        print(f"  Failed: {total_failed} records")

    return 0 if total_failed == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
