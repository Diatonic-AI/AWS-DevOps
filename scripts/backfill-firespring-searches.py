#!/usr/bin/env python3
"""
Backfill Firespring Searches from S3 to DynamoDB

The extractor Lambda has been writing search data to S3 but not DynamoDB.
This script processes all existing S3 search files and populates the DynamoDB table.

Usage:
    python3 backfill-firespring-searches.py --dry-run
    python3 backfill-firespring-searches.py --limit 100
    python3 backfill-firespring-searches.py  # Process all
"""

import argparse
import boto3
import json
import time
from datetime import datetime

# Configuration
BUCKET = 'firespring-backdoor-data-30511389'
SEARCHES_TABLE = 'firespring-backdoor-searches-dev'
NETWORK_STATE_TABLE = 'firespring-backdoor-network-state-dev'
REGION = 'us-east-1'

s3_client = boto3.client('s3', region_name=REGION)
dynamodb = boto3.resource('dynamodb', region_name=REGION)

def process_search_file(bucket, key):
    """Download and transform a search file from S3"""
    try:
        response = s3_client.get_object(Bucket=bucket, Key=key)
        data = json.loads(response['Body'].read())

        searches = []

        # Handle different response formats
        if isinstance(data, list) and len(data) > 0:
            data = data[0]

        for date_group in data.get('dates', []):
            for item in date_group.get('items', []):
                search_id = f"search_{item['time']}_{hash(item['item']) % 1000000}"

                searches.append({
                    'search_id': search_id,
                    'search_query': item['item'],
                    'search_type': 'organic',  # All from organic search
                    'timestamp': int(item['time']),
                    'stats_url': item.get('stats_url', ''),
                    'date_range': date_group.get('date', ''),
                    'results_count': 0,  # Not provided by API
                    'search_metadata': {
                        'time_pretty': item.get('time_pretty', ''),
                        'source_file': key
                    },
                    'created_at': int(response['LastModified'].timestamp() * 1000)
                })

        return searches

    except Exception as e:
        print(f"  Error processing {key}: {e}")
        return []


def backfill_searches(dry_run=False, limit=None):
    """Process all search files from S3"""
    searches_table = dynamodb.Table(SEARCHES_TABLE)

    print(f"{'='*60}")
    print(f"Firespring Searches Backfill")
    print(f"Bucket: {BUCKET}")
    print(f"Table: {SEARCHES_TABLE}")
    print(f"Dry Run: {dry_run}")
    print(f"{'='*60}\n")

    # List all search files
    print("Scanning S3 for search files...")
    paginator = s3_client.get_paginator('list_objects_v2')

    files = []
    for page in paginator.paginate(Bucket=BUCKET, Prefix='raw/searches-recent/'):
        files.extend(page.get('Contents', []))

    print(f"Found {len(files)} search files in S3\n")

    if limit:
        files = files[:limit]
        print(f"Limiting to {limit} files\n")

    # Process files
    total_searches = 0
    total_stored = 0
    file_count = 0

    for obj in files:
        key = obj['Key']
        file_count += 1

        searches = process_search_file(BUCKET, key)
        total_searches += len(searches)

        if dry_run:
            print(f"  [{file_count}/{len(files)}] {key}: {len(searches)} searches (DRY RUN)")
            continue

        # Write to DynamoDB in batches
        with searches_table.batch_writer() as batch:
            for search in searches:
                try:
                    batch.put_item(Item=search)
                    total_stored += 1
                except Exception as e:
                    print(f"    Error storing search: {e}")

        if file_count % 10 == 0:
            print(f"  Processed {file_count}/{len(files)} files ({total_stored} searches)")

    print(f"\n{'='*60}")
    print(f"Backfill Complete")
    print(f"Files processed: {file_count}")
    print(f"Searches extracted: {total_searches}")
    print(f"Searches stored: {total_stored}")
    print(f"{'='*60}")

    return {'files': file_count, 'total': total_searches, 'stored': total_stored}


def main():
    parser = argparse.ArgumentParser(description='Backfill Firespring searches from S3')
    parser.add_argument('--dry-run', action='store_true', help='Preview without writing')
    parser.add_argument('--limit', type=int, help='Limit number of files to process')

    args = parser.parse_args()

    result = backfill_searches(dry_run=args.dry_run, limit=args.limit)

    return 0 if result['stored'] > 0 or args.dry_run else 1


if __name__ == '__main__':
    exit(main())
