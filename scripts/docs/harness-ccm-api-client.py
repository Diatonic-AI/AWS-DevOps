#!/usr/bin/env python3
"""
Harness CCM API Client for Cost Optimization and Reporting

This script provides functionality to interact with Harness Cloud Cost Management APIs
for cost reporting, optimization recommendations, and automated cost management.
"""

import os
import json
import requests
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import argparse


class HarnessCCMClient:
    """Client for Harness CCM API operations"""
    
    def __init__(self, api_key: str, account_id: str, base_url: str = "https://app.harness.io"):
        """
        Initialize Harness CCM API client
        
        Args:
            api_key: Harness API key
            account_id: Harness account ID
            base_url: Base URL for Harness API (default: https://app.harness.io)
        """
        self.api_key = api_key
        self.account_id = account_id
        self.base_url = base_url
        self.headers = {
            "x-api-key": api_key,
            "Content-Type": "application/json"
        }
    
    def _make_request(self, method: str, endpoint: str, **kwargs) -> requests.Response:
        """Make HTTP request to Harness API"""
        url = f"{self.base_url}{endpoint}"
        response = requests.request(method, url, headers=self.headers, **kwargs)
        response.raise_for_status()
        return response
    
    def get_cost_overview(self, time_period: int = 30, group_by: str = "Service") -> Dict:
        """
        Get cost overview for the specified time period
        
        Args:
            time_period: Number of days to look back (default: 30)
            group_by: Grouping dimension (Service, Account, Region, etc.)
        
        Returns:
            Dictionary containing cost overview data
        """
        end_date = datetime.now()
        start_date = end_date - timedelta(days=time_period)
        
        payload = {
            "filters": [
                {
                    "field": "startTime",
                    "operator": "GREATER_THAN_OR_EQUAL_TO", 
                    "values": [start_date.strftime("%Y-%m-%dT%H:%M:%SZ")]
                },
                {
                    "field": "endTime",
                    "operator": "LESS_THAN_OR_EQUAL_TO",
                    "values": [end_date.strftime("%Y-%m-%dT%H:%M:%SZ")]
                }
            ],
            "groupBy": [
                {
                    "field": group_by,
                    "type": "DIMENSION"
                }
            ],
            "aggregateFunction": [
                {
                    "operationType": "SUM",
                    "columnName": "billingAmount"
                }
            ]
        }
        
        endpoint = f"/gateway/ccm/api/perspectiveReport?routingId={self.account_id}&accountIdentifier={self.account_id}"
        response = self._make_request("POST", endpoint, json=payload)
        return response.json()
    
    def get_cost_recommendations(self, recommendation_type: str = "EC2_RIGHTSIZING") -> Dict:
        """
        Get cost optimization recommendations
        
        Args:
            recommendation_type: Type of recommendations to fetch
        
        Returns:
            Dictionary containing recommendations data
        """
        endpoint = f"/gateway/ccm/api/recommendation?routingId={self.account_id}&accountIdentifier={self.account_id}"
        
        params = {
            "type": recommendation_type,
            "offset": 0,
            "limit": 50
        }
        
        response = self._make_request("GET", endpoint, params=params)
        return response.json()
    
    def get_autostopping_resources(self) -> Dict:
        """Get AutoStopping resources and their savings"""
        endpoint = f"/gateway/ccm/api/autostopping/resources?routingId={self.account_id}&accountIdentifier={self.account_id}"
        response = self._make_request("GET", endpoint)
        return response.json()
    
    def create_autostopping_rule(self, rule_config: Dict) -> Dict:
        """
        Create an AutoStopping rule
        
        Args:
            rule_config: Configuration for the AutoStopping rule
        
        Returns:
            Dictionary containing created rule details
        """
        endpoint = f"/gateway/ccm/api/autostopping/rule?routingId={self.account_id}&accountIdentifier={self.account_id}"
        response = self._make_request("POST", endpoint, json=rule_config)
        return response.json()
    
    def get_budgets(self) -> Dict:
        """Get all cost budgets"""
        endpoint = f"/gateway/ccm/api/budgets?routingId={self.account_id}&accountIdentifier={self.account_id}"
        response = self._make_request("GET", endpoint)
        return response.json()
    
    def create_budget_alert(self, budget_config: Dict) -> Dict:
        """
        Create a budget alert
        
        Args:
            budget_config: Configuration for the budget alert
        
        Returns:
            Dictionary containing created budget details
        """
        endpoint = f"/gateway/ccm/api/budgets?routingId={self.account_id}&accountIdentifier={self.account_id}"
        response = self._make_request("POST", endpoint, json=budget_config)
        return response.json()
    
    def get_cost_anomalies(self, days_back: int = 7) -> Dict:
        """
        Get cost anomalies detected in the specified period
        
        Args:
            days_back: Number of days to look back for anomalies
        
        Returns:
            Dictionary containing anomaly data
        """
        end_date = datetime.now()
        start_date = end_date - timedelta(days=days_back)
        
        endpoint = f"/gateway/ccm/api/anomalies?routingId={self.account_id}&accountIdentifier={self.account_id}"
        
        params = {
            "startTime": start_date.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "endTime": end_date.strftime("%Y-%m-%dT%H:%M:%SZ")
        }
        
        response = self._make_request("GET", endpoint, params=params)
        return response.json()


def create_sample_autostopping_rule() -> Dict:
    """Create a sample AutoStopping rule configuration"""
    return {
        "name": "Dev Environment Auto-Stop",
        "description": "Auto-stop development environment instances during off-hours",
        "cloudConnectorId": "aws-devops-ccm",
        "category": "EC2",
        "resourceType": "Instance",
        "resourceIds": [],  # Will be filled with actual instance IDs
        "schedule": {
            "type": "FIXED",
            "startTime": "09:00",
            "endTime": "18:00",
            "timezone": "America/New_York",
            "weekdays": ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY"]
        },
        "conditions": [
            {
                "type": "CPU_UTILIZATION",
                "threshold": 5.0,
                "duration": 30  # minutes
            }
        ],
        "actions": [
            {
                "type": "STOP_INSTANCE"
            }
        ]
    }


def create_sample_budget_alert() -> Dict:
    """Create a sample budget alert configuration"""
    return {
        "name": "AWS Monthly Budget Alert",
        "description": "Alert when AWS costs exceed $100 per month",
        "budgetAmount": 100.0,
        "currency": "USD",
        "period": "MONTHLY",
        "budgetScope": {
            "cloudConnectorId": "aws-devops-ccm",
            "filters": [
                {
                    "field": "cloudProvider",
                    "operator": "EQUALS",
                    "values": ["AWS"]
                }
            ]
        },
        "alertThresholds": [
            {
                "percentage": 50.0,
                "alertType": "ACTUAL_COST",
                "alertChannels": ["email"]
            },
            {
                "percentage": 80.0,
                "alertType": "ACTUAL_COST",
                "alertChannels": ["email", "slack"]
            },
            {
                "percentage": 100.0,
                "alertType": "FORECASTED_COST",
                "alertChannels": ["email", "slack"]
            }
        ],
        "notificationChannels": {
            "email": ["admin@example.com"],
            "slack": ["#aws-costs"]
        }
    }


def main():
    """Main function for CLI usage"""
    parser = argparse.ArgumentParser(description="Harness CCM API Client")
    parser.add_argument("--api-key", required=True, help="Harness API key")
    parser.add_argument("--account-id", required=True, help="Harness account ID")
    parser.add_argument("--action", required=True, 
                       choices=["cost-overview", "recommendations", "autostopping", 
                               "budgets", "anomalies", "create-rule", "create-budget"],
                       help="Action to perform")
    parser.add_argument("--days", type=int, default=30, 
                       help="Number of days for historical data (default: 30)")
    parser.add_argument("--group-by", default="Service",
                       help="Group by dimension for cost overview (default: Service)")
    parser.add_argument("--output", choices=["json", "table"], default="json",
                       help="Output format (default: json)")
    
    args = parser.parse_args()
    
    # Initialize client
    client = HarnessCCMClient(args.api_key, args.account_id)
    
    try:
        if args.action == "cost-overview":
            result = client.get_cost_overview(args.days, args.group_by)
            print("📊 Cost Overview:")
            
        elif args.action == "recommendations":
            result = client.get_cost_recommendations()
            print("💡 Cost Optimization Recommendations:")
            
        elif args.action == "autostopping":
            result = client.get_autostopping_resources()
            print("⏹️ AutoStopping Resources:")
            
        elif args.action == "budgets":
            result = client.get_budgets()
            print("💰 Budget Alerts:")
            
        elif args.action == "anomalies":
            result = client.get_cost_anomalies(args.days)
            print("🚨 Cost Anomalies:")
            
        elif args.action == "create-rule":
            rule_config = create_sample_autostopping_rule()
            result = client.create_autostopping_rule(rule_config)
            print("✅ Created AutoStopping Rule:")
            
        elif args.action == "create-budget":
            budget_config = create_sample_budget_alert()
            result = client.create_budget_alert(budget_config)
            print("✅ Created Budget Alert:")
        
        if args.output == "json":
            print(json.dumps(result, indent=2))
        else:
            # Simple table output for basic data
            if isinstance(result, dict) and "data" in result:
                for item in result.get("data", []):
                    print(f"  - {item}")
            else:
                print(f"  {result}")
                
    except requests.exceptions.RequestException as e:
        print(f"❌ API Error: {e}")
    except Exception as e:
        print(f"❌ Error: {e}")


if __name__ == "__main__":
    # Example usage if run directly
    print("""
🌟 Harness CCM API Client

Examples:
  python harness-ccm-api-client.py --api-key YOUR_API_KEY --account-id ACCOUNT_ID --action cost-overview
  python harness-ccm-api-client.py --api-key YOUR_API_KEY --account-id ACCOUNT_ID --action recommendations
  python harness-ccm-api-client.py --api-key YOUR_API_KEY --account-id ACCOUNT_ID --action anomalies --days 7
  
Set environment variables:
  export HARNESS_API_KEY=your_api_key_here
  export HARNESS_ACCOUNT_ID=your_account_id_here
""")
    
    # Check if environment variables are set
    api_key = os.getenv("HARNESS_API_KEY")
    account_id = os.getenv("HARNESS_ACCOUNT_ID")
    
    if api_key and account_id:
        import sys
        if len(sys.argv) == 1:
            # If no arguments provided, show demo
            client = HarnessCCMClient(api_key, account_id)
            print("\n🚀 Running demo with environment variables...")
            
            try:
                print("\n📊 Getting cost overview...")
                overview = client.get_cost_overview(30, "Service")
                print(f"   Total records: {len(overview.get('data', []))}")
                
                print("\n💡 Getting recommendations...")
                recommendations = client.get_cost_recommendations()
                print(f"   Total recommendations: {len(recommendations.get('data', []))}")
                
            except Exception as e:
                print(f"❌ Demo error: {e}")
    else:
        main()