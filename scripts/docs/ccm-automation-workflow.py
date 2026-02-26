#!/usr/bin/env python3
"""
CCM Automation Workflow

This script provides automated workflows for Harness CCM cost optimization
and reporting, including scheduled reports, anomaly detection, and automated
cost optimization actions.
"""

import os
import json
import time
import schedule
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from harness_ccm_api_client import HarnessCCMClient
import smtplib
from email.mime.text import MimeText
from email.mime.multipart import MimeMultipart
from email.mime.base import MimeBase
from email import encoders
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('ccm-automation.log'),
        logging.StreamHandler()
    ]
)

class CCMAutomationWorkflow:
    """Automation workflow manager for Harness CCM"""
    
    def __init__(self, api_key: str, account_id: str):
        """Initialize the automation workflow"""
        self.client = HarnessCCMClient(api_key, account_id)
        self.logger = logging.getLogger(__name__)
        
        # Email configuration
        self.email_config = {
            'smtp_server': os.getenv('SMTP_SERVER', 'smtp.gmail.com'),
            'smtp_port': int(os.getenv('SMTP_PORT', '587')),
            'sender_email': os.getenv('SENDER_EMAIL'),
            'sender_password': os.getenv('SENDER_PASSWORD'),
            'recipient_emails': os.getenv('RECIPIENT_EMAILS', '').split(',')
        }
        
        # Cost thresholds
        self.thresholds = {
            'daily_budget': float(os.getenv('DAILY_BUDGET', '50.0')),
            'monthly_budget': float(os.getenv('MONTHLY_BUDGET', '1000.0')),
            'anomaly_threshold': float(os.getenv('ANOMALY_THRESHOLD', '20.0')),  # % increase
            'cpu_threshold': float(os.getenv('CPU_THRESHOLD', '5.0')),  # % utilization
            'rightsizing_savings_threshold': float(os.getenv('MIN_SAVINGS_THRESHOLD', '10.0'))  # $ per month
        }
    
    def send_email_notification(self, subject: str, body: str, attachments: List[str] = None):
        """Send email notification"""
        if not self.email_config['sender_email'] or not self.email_config['recipient_emails']:
            self.logger.warning("Email configuration incomplete, skipping notification")
            return
        
        try:
            msg = MimeMultipart()
            msg['From'] = self.email_config['sender_email']
            msg['To'] = ', '.join(self.email_config['recipient_emails'])
            msg['Subject'] = subject
            
            msg.attach(MimeText(body, 'html'))
            
            # Add attachments
            if attachments:
                for file_path in attachments:
                    if os.path.exists(file_path):
                        with open(file_path, 'rb') as attachment:
                            part = MimeBase('application', 'octet-stream')
                            part.set_payload(attachment.read())
                            
                        encoders.encode_base64(part)
                        part.add_header(
                            'Content-Disposition',
                            f'attachment; filename= {os.path.basename(file_path)}'
                        )
                        msg.attach(part)
            
            server = smtplib.SMTP(self.email_config['smtp_server'], self.email_config['smtp_port'])
            server.starttls()
            server.login(self.email_config['sender_email'], self.email_config['sender_password'])
            server.send_message(msg)
            server.quit()
            
            self.logger.info(f"Email notification sent: {subject}")
            
        except Exception as e:
            self.logger.error(f"Failed to send email notification: {e}")
    
    def generate_daily_cost_report(self):
        """Generate daily cost report"""
        try:
            self.logger.info("Generating daily cost report...")
            
            # Get cost overview for the last 7 days
            cost_data = self.client.get_cost_overview(7, "Service")
            
            # Get yesterday's cost
            yesterday_costs = self.client.get_cost_overview(1, "Service")
            
            # Get anomalies for the last 24 hours
            anomalies = self.client.get_cost_anomalies(1)
            
            # Get recommendations
            recommendations = self.client.get_cost_recommendations()
            
            # Generate report
            report_data = {
                'date': datetime.now().strftime('%Y-%m-%d'),
                'yesterday_total_cost': self._calculate_total_cost(yesterday_costs),
                'week_total_cost': self._calculate_total_cost(cost_data),
                'top_services': self._get_top_services(cost_data, 5),
                'anomalies_count': len(anomalies.get('data', [])),
                'recommendations_count': len(recommendations.get('data', [])),
                'budget_status': self._check_budget_status()
            }
            
            # Save report
            report_file = f"daily_cost_report_{datetime.now().strftime('%Y%m%d')}.json"
            with open(report_file, 'w') as f:
                json.dump(report_data, f, indent=2)
            
            # Generate email report
            email_body = self._generate_email_report(report_data)
            subject = f"Daily Cost Report - {datetime.now().strftime('%Y-%m-%d')}"
            
            self.send_email_notification(subject, email_body, [report_file])
            
            self.logger.info("Daily cost report generated successfully")
            return report_data
            
        except Exception as e:
            self.logger.error(f"Error generating daily cost report: {e}")
            return None
    
    def check_and_alert_anomalies(self):
        """Check for cost anomalies and send alerts"""
        try:
            self.logger.info("Checking for cost anomalies...")
            
            anomalies = self.client.get_cost_anomalies(1)
            
            if anomalies.get('data'):
                high_impact_anomalies = [
                    anomaly for anomaly in anomalies['data']
                    if anomaly.get('impact', 0) > self.thresholds['anomaly_threshold']
                ]
                
                if high_impact_anomalies:
                    subject = "🚨 Cost Anomaly Alert - Immediate Attention Required"
                    body = self._generate_anomaly_alert(high_impact_anomalies)
                    
                    self.send_email_notification(subject, body)
                    self.logger.warning(f"High impact anomalies detected: {len(high_impact_anomalies)}")
            
        except Exception as e:
            self.logger.error(f"Error checking for anomalies: {e}")
    
    def automated_rightsizing_recommendations(self):
        """Process and apply automated rightsizing recommendations"""
        try:
            self.logger.info("Processing rightsizing recommendations...")
            
            recommendations = self.client.get_cost_recommendations("EC2_RIGHTSIZING")
            
            if not recommendations.get('data'):
                self.logger.info("No rightsizing recommendations found")
                return
            
            actionable_recommendations = [
                rec for rec in recommendations['data']
                if rec.get('monthlySavings', 0) > self.thresholds['rightsizing_savings_threshold']
            ]
            
            if actionable_recommendations:
                # Generate detailed report
                report = self._generate_rightsizing_report(actionable_recommendations)
                
                # Save report
                report_file = f"rightsizing_recommendations_{datetime.now().strftime('%Y%m%d')}.json"
                with open(report_file, 'w') as f:
                    json.dump(report, f, indent=2)
                
                subject = "💰 Rightsizing Recommendations - Potential Savings Available"
                body = self._generate_rightsizing_email(report)
                
                self.send_email_notification(subject, body, [report_file])
                
                self.logger.info(f"Found {len(actionable_recommendations)} actionable rightsizing recommendations")
            
        except Exception as e:
            self.logger.error(f"Error processing rightsizing recommendations: {e}")
    
    def automated_autostopping_management(self):
        """Manage and optimize AutoStopping rules"""
        try:
            self.logger.info("Managing AutoStopping rules...")
            
            # Get current AutoStopping resources
            resources = self.client.get_autostopping_resources()
            
            # Check for idle resources without AutoStopping rules
            idle_resources = self._identify_idle_resources()
            
            if idle_resources:
                # Create AutoStopping rules for idle resources
                for resource in idle_resources:
                    if resource['cpu_utilization'] < self.thresholds['cpu_threshold']:
                        rule_config = self._create_autostopping_rule_config(resource)
                        
                        try:
                            result = self.client.create_autostopping_rule(rule_config)
                            self.logger.info(f"Created AutoStopping rule for {resource['instance_id']}")
                        except Exception as e:
                            self.logger.warning(f"Failed to create AutoStopping rule for {resource['instance_id']}: {e}")
            
            # Generate summary
            summary = {
                'date': datetime.now().strftime('%Y-%m-%d'),
                'total_autostopping_resources': len(resources.get('data', [])),
                'new_rules_created': len(idle_resources),
                'potential_monthly_savings': sum(r.get('estimated_savings', 0) for r in idle_resources)
            }
            
            if summary['new_rules_created'] > 0:
                subject = "⏹️ AutoStopping Rules Created - New Savings Opportunities"
                body = self._generate_autostopping_email(summary, idle_resources)
                self.send_email_notification(subject, body)
            
        except Exception as e:
            self.logger.error(f"Error managing AutoStopping rules: {e}")
    
    def weekly_optimization_summary(self):
        """Generate weekly optimization summary"""
        try:
            self.logger.info("Generating weekly optimization summary...")
            
            # Get data for the last 7 days
            cost_data = self.client.get_cost_overview(7, "Service")
            recommendations = self.client.get_cost_recommendations()
            autostopping = self.client.get_autostopping_resources()
            
            # Calculate metrics
            summary = {
                'week_ending': datetime.now().strftime('%Y-%m-%d'),
                'total_weekly_cost': self._calculate_total_cost(cost_data),
                'cost_by_service': self._get_top_services(cost_data, 10),
                'total_recommendations': len(recommendations.get('data', [])),
                'potential_monthly_savings': sum(
                    rec.get('monthlySavings', 0) for rec in recommendations.get('data', [])
                ),
                'autostopping_savings': sum(
                    res.get('savings', 0) for res in autostopping.get('data', [])
                ),
                'optimization_score': self._calculate_optimization_score()
            }
            
            # Save weekly report
            report_file = f"weekly_optimization_summary_{datetime.now().strftime('%Y%m%d')}.json"
            with open(report_file, 'w') as f:
                json.dump(summary, f, indent=2)
            
            subject = f"📊 Weekly Cost Optimization Summary - {summary['week_ending']}"
            body = self._generate_weekly_summary_email(summary)
            
            self.send_email_notification(subject, body, [report_file])
            
            self.logger.info("Weekly optimization summary generated successfully")
            
        except Exception as e:
            self.logger.error(f"Error generating weekly summary: {e}")
    
    def _calculate_total_cost(self, cost_data: Dict) -> float:
        """Calculate total cost from cost data"""
        if not cost_data.get('data'):
            return 0.0
        
        total = 0.0
        for item in cost_data['data']:
            total += item.get('cost', 0.0)
        
        return round(total, 2)
    
    def _get_top_services(self, cost_data: Dict, limit: int = 5) -> List[Dict]:
        """Get top services by cost"""
        if not cost_data.get('data'):
            return []
        
        services = sorted(
            cost_data['data'],
            key=lambda x: x.get('cost', 0),
            reverse=True
        )
        
        return services[:limit]
    
    def _check_budget_status(self) -> Dict:
        """Check budget status against thresholds"""
        try:
            budgets = self.client.get_budgets()
            
            if not budgets.get('data'):
                return {'status': 'no_budget_configured'}
            
            # For simplicity, check the first budget
            budget = budgets['data'][0]
            spent = budget.get('actualSpend', 0)
            budget_amount = budget.get('budgetAmount', 0)
            
            if budget_amount > 0:
                utilization = (spent / budget_amount) * 100
                
                if utilization >= 100:
                    status = 'exceeded'
                elif utilization >= 80:
                    status = 'warning'
                elif utilization >= 50:
                    status = 'caution'
                else:
                    status = 'normal'
                
                return {
                    'status': status,
                    'utilization_percent': round(utilization, 1),
                    'spent': spent,
                    'budget': budget_amount,
                    'remaining': budget_amount - spent
                }
            
        except Exception as e:
            self.logger.warning(f"Error checking budget status: {e}")
        
        return {'status': 'unknown'}
    
    def _generate_email_report(self, data: Dict) -> str:
        """Generate HTML email report"""
        return f"""
        <html>
        <body>
            <h2>Daily Cost Report - {data['date']}</h2>
            
            <h3>💰 Cost Summary</h3>
            <ul>
                <li><strong>Yesterday's Total Cost:</strong> ${data['yesterday_total_cost']:.2f}</li>
                <li><strong>7-Day Total Cost:</strong> ${data['week_total_cost']:.2f}</li>
            </ul>
            
            <h3>🔝 Top Services</h3>
            <ul>
                {self._format_services_list(data['top_services'])}
            </ul>
            
            <h3>🚨 Alerts</h3>
            <ul>
                <li><strong>Cost Anomalies:</strong> {data['anomalies_count']}</li>
                <li><strong>Recommendations:</strong> {data['recommendations_count']}</li>
            </ul>
            
            <h3>📊 Budget Status</h3>
            <p>{self._format_budget_status(data['budget_status'])}</p>
            
            <hr>
            <p><em>Generated by Harness CCM Automation at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</em></p>
        </body>
        </html>
        """
    
    def _format_services_list(self, services: List[Dict]) -> str:
        """Format services list for email"""
        if not services:
            return "<li>No data available</li>"
        
        items = []
        for service in services:
            items.append(f"<li>{service.get('name', 'Unknown')}: ${service.get('cost', 0):.2f}</li>")
        
        return '\n'.join(items)
    
    def _format_budget_status(self, budget: Dict) -> str:
        """Format budget status for email"""
        if budget.get('status') == 'no_budget_configured':
            return "No budget configured"
        
        status_icons = {
            'normal': '✅',
            'caution': '⚠️',
            'warning': '🔶',
            'exceeded': '🚨',
            'unknown': '❓'
        }
        
        icon = status_icons.get(budget.get('status', 'unknown'), '❓')
        
        return f"{icon} {budget.get('utilization_percent', 0):.1f}% utilized (${budget.get('spent', 0):.2f} / ${budget.get('budget', 0):.2f})"
    
    def _identify_idle_resources(self) -> List[Dict]:
        """Identify idle resources that could benefit from AutoStopping"""
        # This would typically query AWS CloudWatch or other monitoring services
        # For now, return sample data
        return []
    
    def _create_autostopping_rule_config(self, resource: Dict) -> Dict:
        """Create AutoStopping rule configuration for a resource"""
        return {
            "name": f"Auto-generated rule for {resource['instance_id']}",
            "description": f"Automatically generated rule for idle resource {resource['instance_id']}",
            "cloudConnectorId": "aws-devops-ccm",
            "category": "EC2",
            "resourceType": "Instance",
            "resourceIds": [resource['instance_id']],
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
                    "threshold": self.thresholds['cpu_threshold'],
                    "duration": 30
                }
            ],
            "actions": [
                {
                    "type": "STOP_INSTANCE"
                }
            ]
        }
    
    def _calculate_optimization_score(self) -> int:
        """Calculate optimization score (0-100)"""
        # Simplified scoring algorithm
        # In practice, this would consider multiple factors
        return 75
    
    def _generate_anomaly_alert(self, anomalies: List[Dict]) -> str:
        """Generate anomaly alert email"""
        anomaly_list = '\n'.join([
            f"<li>{anomaly.get('service', 'Unknown')}: ${anomaly.get('impact', 0):.2f} increase</li>"
            for anomaly in anomalies
        ])
        
        return f"""
        <html>
        <body>
            <h2>🚨 Cost Anomaly Alert</h2>
            <p>The following cost anomalies have been detected:</p>
            <ul>{anomaly_list}</ul>
            <p>Please review these anomalies and take appropriate action.</p>
        </body>
        </html>
        """
    
    def _generate_rightsizing_report(self, recommendations: List[Dict]) -> Dict:
        """Generate rightsizing recommendations report"""
        return {
            'date': datetime.now().strftime('%Y-%m-%d'),
            'recommendations': recommendations,
            'total_potential_savings': sum(rec.get('monthlySavings', 0) for rec in recommendations),
            'count': len(recommendations)
        }
    
    def _generate_rightsizing_email(self, report: Dict) -> str:
        """Generate rightsizing email"""
        return f"""
        <html>
        <body>
            <h2>💰 Rightsizing Recommendations</h2>
            <p>Found {report['count']} recommendations with potential monthly savings of ${report['total_potential_savings']:.2f}</p>
            <p>Please review the attached detailed report.</p>
        </body>
        </html>
        """
    
    def _generate_autostopping_email(self, summary: Dict, resources: List[Dict]) -> str:
        """Generate AutoStopping email"""
        return f"""
        <html>
        <body>
            <h2>⏹️ AutoStopping Rules Created</h2>
            <p>Created {summary['new_rules_created']} new AutoStopping rules with potential monthly savings of ${summary['potential_monthly_savings']:.2f}</p>
        </body>
        </html>
        """
    
    def _generate_weekly_summary_email(self, summary: Dict) -> str:
        """Generate weekly summary email"""
        return f"""
        <html>
        <body>
            <h2>📊 Weekly Cost Optimization Summary</h2>
            
            <h3>💰 Cost Overview</h3>
            <ul>
                <li><strong>Total Weekly Cost:</strong> ${summary['total_weekly_cost']:.2f}</li>
                <li><strong>Optimization Score:</strong> {summary['optimization_score']}/100</li>
            </ul>
            
            <h3>💡 Optimization Opportunities</h3>
            <ul>
                <li><strong>Active Recommendations:</strong> {summary['total_recommendations']}</li>
                <li><strong>Potential Monthly Savings:</strong> ${summary['potential_monthly_savings']:.2f}</li>
                <li><strong>AutoStopping Savings:</strong> ${summary['autostopping_savings']:.2f}</li>
            </ul>
            
            <p>Detailed report attached.</p>
        </body>
        </html>
        """

def setup_scheduled_jobs(workflow: CCMAutomationWorkflow):
    """Set up scheduled jobs"""
    # Daily jobs
    schedule.every().day.at("08:00").do(workflow.generate_daily_cost_report)
    schedule.every().day.at("09:00").do(workflow.check_and_alert_anomalies)
    schedule.every().day.at("10:00").do(workflow.automated_rightsizing_recommendations)
    schedule.every().day.at("11:00").do(workflow.automated_autostopping_management)
    
    # Weekly jobs
    schedule.every().monday.at("09:00").do(workflow.weekly_optimization_summary)
    
    logging.info("Scheduled jobs configured:")
    logging.info("- Daily cost report: 08:00")
    logging.info("- Anomaly check: 09:00")
    logging.info("- Rightsizing recommendations: 10:00")
    logging.info("- AutoStopping management: 11:00")
    logging.info("- Weekly summary: Monday 09:00")

def main():
    """Main execution function"""
    # Check for required environment variables
    api_key = os.getenv('HARNESS_API_KEY')
    account_id = os.getenv('HARNESS_ACCOUNT_ID')
    
    if not api_key or not account_id:
        print("❌ Error: HARNESS_API_KEY and HARNESS_ACCOUNT_ID environment variables are required")
        print("\nSet them with:")
        print("export HARNESS_API_KEY=your_api_key_here")
        print("export HARNESS_ACCOUNT_ID=your_account_id_here")
        return
    
    # Initialize workflow
    workflow = CCMAutomationWorkflow(api_key, account_id)
    
    # Set up scheduled jobs
    setup_scheduled_jobs(workflow)
    
    print("🚀 CCM Automation Workflow started")
    print("📅 Scheduled jobs configured and running")
    print("📊 Daily reports will be generated at 08:00")
    print("🚨 Anomaly detection runs at 09:00")
    print("💡 Optimization analysis runs at 10:00-11:00")
    print("📈 Weekly summaries on Monday mornings")
    print("\nPress Ctrl+C to stop")
    
    try:
        while True:
            schedule.run_pending()
            time.sleep(60)  # Check every minute
    except KeyboardInterrupt:
        print("\n👋 CCM Automation Workflow stopped")

if __name__ == "__main__":
    main()