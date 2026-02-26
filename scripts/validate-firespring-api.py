#!/usr/bin/env python3
"""
Firespring API Validation Script

Tests all API endpoints and data types to verify what data is available
and ensure Lambda extractors are calling the correct endpoints.

Usage:
    # Get sitekey first from site preferences
    python3 validate-firespring-api.py --sitekey YOUR_SITEKEY_HERE

    # Test specific data types
    python3 validate-firespring-api.py --sitekey YOUR_KEY --types searches-recent,traffic-sources
"""

import argparse
import requests
import json
from datetime import datetime, timedelta

# Configuration
API_BASE = "http://analytics.firespring.com/api/stats/4"
SITE_ID = "98718"

# All available data types
AVAILABLE_TYPES = {
    # Chronological (what extractor uses)
    'visitors-list': 'List of all visitors with full details',
    'actions-list': 'List of all page views, clicks, downloads',
    'searches-recent': 'Recent search queries that led to site',
    'searches-unique': 'First-time search queries',
    'links-recent': 'Recent referral links',

    # Popular (aggregated)
    'searches': 'Top search queries (aggregated)',
    'traffic-sources': 'Traffic source breakdown',
    'pages': 'Top pages visited',
    'countries': 'Geographic distribution',
    'web-browsers': 'Browser breakdown',
    'operating-systems': 'OS breakdown',

    # Tallies
    'visitors': 'Total visitor count',
    'actions': 'Total action count',
    'bounce-rate': 'Bounce rate percentage',

    # Segmentation
    'segmentation': 'Custom visitor segments',

    # Premium features
    'hostname': 'Visitor hostnames (premium)',
    'organizations': 'Visitor organizations (premium)',
}

def test_api_endpoint(sitekey, data_type, date_range='last-7-days', limit=10):
    """Test a single Firespring API endpoint"""
    params = {
        'site_id': SITE_ID,
        'sitekey': sitekey,
        'type': data_type,
        'date': date_range,
        'limit': limit,
        'output': 'json'
    }

    try:
        url = f"{API_BASE}?" + "&".join([f"{k}={v}" for k, v in params.items()])
        print(f"  Testing: {data_type}")
        print(f"  URL: {url[:100]}...")

        response = requests.get(url, timeout=30)

        if response.status_code != 200:
            return {
                'type': data_type,
                'status': 'error',
                'http_code': response.status_code,
                'message': response.text[:200]
            }

        data = response.json()

        # Analyze response
        record_count = 0
        if isinstance(data, list):
            record_count = len(data)
        elif isinstance(data, dict):
            if 'dates' in data:
                for date_group in data.get('dates', []):
                    record_count += len(date_group.get('items', []))
            elif 'value' in data:
                record_count = 1

        return {
            'type': data_type,
            'status': 'success',
            'http_code': 200,
            'records': record_count,
            'response_type': type(data).__name__,
            'sample_keys': list(data.keys())[:10] if isinstance(data, dict) else ['array'],
            'has_data': record_count > 0
        }

    except Exception as e:
        return {
            'type': data_type,
            'status': 'error',
            'message': str(e)
        }


def validate_extractor_data_types(sitekey):
    """Validate the data types that the Lambda extractor is configured to pull"""
    print("="*60)
    print("VALIDATING LAMBDA EXTRACTOR DATA TYPES")
    print("="*60)
    print()

    # Data types the extractor should be pulling (from Lambda response)
    extractor_types = [
        'visitors-list',
        'actions-list',
        'traffic-sources',
        'searches-recent',
        'segmentation',
        # Add more as needed
    ]

    results = []
    for data_type in extractor_types:
        result = test_api_endpoint(sitekey, data_type)
        results.append(result)

        status_icon = '✓' if result['status'] == 'success' and result.get('has_data') else '❌'
        print(f"{status_icon} {data_type}: {result.get('records', 0)} records")
        print()

    return results


def check_network_state_availability(sitekey):
    """Check if network-state data is available from Firespring API"""
    print("="*60)
    print("CHECKING NETWORK-STATE DATA AVAILABILITY")
    print("="*60)
    print()

    # Network state is NOT a standard Firespring data type
    # The table might be for custom tracking, not API data
    print("NOTE: 'network-state' is NOT a documented Firespring API data type")
    print("Available network-related types:")
    print("  - hostname (premium feature)")
    print("  - organizations (premium feature)")
    print()

    # Test if hostname/organizations work
    for data_type in ['hostname', 'organizations']:
        result = test_api_endpoint(sitekey, data_type, limit=5)
        status = '✓' if result['status'] == 'success' else '❌'
        print(f"{status} {data_type}: {result.get('records', 0)} records")

    print()
    print("CONCLUSION:")
    print("  firespring-backdoor-network-state-dev table appears to be")
    print("  for custom application logic, not Firespring API data.")
    print("  Recommend removing table or using for app-specific purposes.")


def analyze_searches_discrepancy(sitekey):
    """Understand why searches show 'stored: 0' in extractor"""
    print("="*60)
    print("ANALYZING SEARCHES DATA FLOW")
    print("="*60)
    print()

    # Test different search endpoints
    search_types = [
        'searches-recent',  # Used by extractor
        'searches',         # Popular searches
        'searches-keywords', # Individual keywords
    ]

    for search_type in search_types:
        result = test_api_endpoint(sitekey, search_type, limit=100)
        print(f"{search_type}:")
        print(f"  Status: {result['status']}")
        print(f"  Records: {result.get('records', 0)}")
        if result.get('has_data'):
            print(f"  ✓ Data available")
        else:
            print(f"  ⚠️ No data or empty response")
        print()


def main():
    parser = argparse.ArgumentParser(description='Validate Firespring API integration')
    parser.add_argument('--sitekey', type=str, required=True, help='Firespring sitekey (get from site preferences)')
    parser.add_argument('--types', type=str, help='Comma-separated data types to test')
    parser.add_argument('--all', action='store_true', help='Test all available data types')

    args = parser.parse_args()

    print(f"Firespring API Validation")
    print(f"Site ID: {SITE_ID}")
    print(f"Sitekey: {args.sitekey[:4]}...{args.sitekey[-4:]}")
    print(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()

    if args.types:
        types_to_test = args.types.split(',')
        for data_type in types_to_test:
            result = test_api_endpoint(args.sitekey, data_type.strip())
            print(json.dumps(result, indent=2))
    elif args.all:
        for data_type in AVAILABLE_TYPES.keys():
            result = test_api_endpoint(args.sitekey, data_type)
            print(f"{data_type}: {result.get('records', 0)} records")
    else:
        # Run standard validation
        results = validate_extractor_data_types(args.sitekey)
        analyze_searches_discrepancy(args.sitekey)
        check_network_state_availability(args.sitekey)

        # Summary
        print("="*60)
        print("VALIDATION SUMMARY")
        print("="*60)
        working = sum(1 for r in results if r['status'] == 'success' and r.get('has_data'))
        print(f"Working endpoints: {working}/{len(results)}")
        print()

        failing = [r for r in results if r['status'] != 'success' or not r.get('has_data')]
        if failing:
            print("Issues found:")
            for r in failing:
                print(f"  ❌ {r['type']}: {r.get('message', 'No data')}")

    return 0


if __name__ == '__main__':
    exit(main())
