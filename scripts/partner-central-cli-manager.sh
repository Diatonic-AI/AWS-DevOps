#!/bin/bash
set -euo pipefail

# AWS Partner Central CLI Manager
# Comprehensive programmatic management using Partner Central APIs

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${BLUE}"
cat <<'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║   AWS Partner Central - CLI Manager                         ║
║   Full Programmatic Control via AWS APIs                    ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Configuration
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
REGION="${AWS_REGION:-us-east-1}"  # Partner Central uses us-east-1

echo -e "${YELLOW}Configuration:${NC}"
echo "  Account ID: $ACCOUNT_ID"
echo "  Region: $REGION"
echo ""

# ═══════════════════════════════════════════════════════════
# PARTNER ACCOUNT MANAGEMENT
# ═══════════════════════════════════════════════════════════

get_partner_profile() {
    echo -e "${BLUE}═══ Partner Account Information ═══${NC}"

    echo "Getting partner profile..."
    aws partnercentral-account get-partner \
        --region "$REGION" \
        --output json 2>/dev/null | jq '.' || echo "No partner profile found or access denied"

    echo ""
}

get_alliance_lead() {
    echo -e "${BLUE}═══ Alliance Lead Contact ═══${NC}"

    aws partnercentral-account get-alliance-lead-contact \
        --region "$REGION" \
        --output json 2>/dev/null | jq '.' || echo "No alliance lead configured"

    echo ""
}

list_connections() {
    echo -e "${BLUE}═══ Partner Connections ═══${NC}"

    echo "Listing partner connections..."
    aws partnercentral-account list-connections \
        --region "$REGION" \
        --output table 2>/dev/null || echo "No connections found or access denied"

    echo ""
}

list_connection_invitations() {
    echo -e "${BLUE}═══ Connection Invitations ═══${NC}"

    echo "Listing pending invitations..."
    aws partnercentral-account list-connection-invitations \
        --region "$REGION" \
        --output table 2>/dev/null || echo "No invitations found"

    echo ""
}

# ═══════════════════════════════════════════════════════════
# OPPORTUNITY MANAGEMENT
# ═══════════════════════════════════════════════════════════

list_opportunities() {
    echo -e "${BLUE}═══ Partner Opportunities ═══${NC}"

    echo "Listing opportunities..."
    aws partnercentral-selling list-opportunities \
        --catalog "AWS" \
        --region "$REGION" \
        --max-results 20 \
        --output table 2>/dev/null || echo "No opportunities found or access denied"

    echo ""
}

create_opportunity() {
    local customer_name="${1:-Sample Customer}"
    local title="${2:-AI/ML Solution Opportunity}"

    echo -e "${BLUE}═══ Creating New Opportunity ═══${NC}"

    cat > /tmp/opportunity.json <<EOF
{
  "Catalog": "AWS",
  "ClientToken": "$(uuidgen)",
  "Customer": {
    "CompanyName": "$customer_name",
    "CountryCode": "US",
    "Industry": "Technology"
  },
  "LifeCycle": {
    "Stage": "Prospect",
    "TargetCloseDate": "$(date -d '+90 days' +%Y-%m-%d)"
  },
  "OpportunityType": "Net New Business",
  "PartnerOpportunityIdentifier": "DIATONIC-$(date +%Y%m%d)-001",
  "PrimaryNeedsFromAws": [
    "Co-Sell - Architectural Validation",
    "Co-Sell - Business Presentation"
  ],
  "Project": {
    "Title": "$title",
    "ExpectedCustomerSpend": [
      {
        "Amount": "50000",
        "CurrencyCode": "USD",
        "Frequency": "Monthly",
        "TargetCompany": "AWS"
      }
    ]
  }
}
EOF

    echo "Creating opportunity from template..."
    aws partnercentral-selling create-opportunity \
        --region "$REGION" \
        --cli-input-json file:///tmp/opportunity.json \
        --output json 2>/dev/null | jq '.' || echo "Failed to create opportunity - check permissions"

    echo ""
}

get_opportunity() {
    local opp_id="$1"

    echo -e "${BLUE}═══ Opportunity Details ═══${NC}"

    aws partnercentral-selling get-opportunity \
        --catalog "AWS" \
        --identifier "$opp_id" \
        --region "$REGION" \
        --output json 2>/dev/null | jq '.' || echo "Opportunity not found"

    echo ""
}

update_opportunity_stage() {
    local opp_id="$1"
    local new_stage="${2:-Qualified}"  # Prospect, Qualified, Technical Validation, etc.

    echo -e "${BLUE}═══ Updating Opportunity Stage ═══${NC}"

    cat > /tmp/update-opp.json <<EOF
{
  "Catalog": "AWS",
  "Identifier": "$opp_id",
  "LifeCycle": {
    "Stage": "$new_stage"
  },
  "LastModifiedDate": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

    aws partnercentral-selling update-opportunity \
        --region "$REGION" \
        --cli-input-json file:///tmp/update-opp.json \
        --output json 2>/dev/null | jq '.' || echo "Failed to update opportunity"

    echo ""
}

# ═══════════════════════════════════════════════════════════
# ENGAGEMENT & REFERRAL MANAGEMENT
# ═══════════════════════════════════════════════════════════

list_engagement_invitations() {
    echo -e "${BLUE}═══ AWS Referral Invitations ═══${NC}"

    echo "Listing engagement invitations from AWS..."
    aws partnercentral-selling list-engagement-invitations \
        --catalog "AWS" \
        --region "$REGION" \
        --max-results 20 \
        --output table 2>/dev/null || echo "No invitations found"

    echo ""
}

get_engagement_invitation() {
    local invitation_id="$1"

    echo -e "${BLUE}═══ Engagement Invitation Details ═══${NC}"

    aws partnercentral-selling get-engagement-invitation \
        --catalog "AWS" \
        --identifier "$invitation_id" \
        --region "$REGION" \
        --output json 2>/dev/null | jq '.'

    echo ""
}

accept_engagement_invitation() {
    local invitation_id="$1"

    echo -e "${BLUE}═══ Accepting AWS Referral ═══${NC}"

    aws partnercentral-selling start-engagement-by-accepting-invitation \
        --catalog "AWS" \
        --identifier "$invitation_id" \
        --region "$REGION" \
        --client-token "$(uuidgen)" \
        --output json 2>/dev/null | jq '.' || echo "Failed to accept invitation"

    echo ""
}

reject_engagement_invitation() {
    local invitation_id="$1"
    local reason="${2:-Not a good fit at this time}"

    echo -e "${BLUE}═══ Rejecting AWS Referral ═══${NC}"

    aws partnercentral-selling reject-engagement-invitation \
        --catalog "AWS" \
        --identifier "$invitation_id" \
        --region "$REGION" \
        --rejection-reason "$reason" \
        --output json 2>/dev/null | jq '.'

    echo ""
}

# ═══════════════════════════════════════════════════════════
# SOLUTION MANAGEMENT
# ═══════════════════════════════════════════════════════════

list_solutions() {
    echo -e "${BLUE}═══ Partner Solutions ═══${NC}"

    echo "Listing partner solutions..."
    aws partnercentral-selling list-solutions \
        --catalog "AWS" \
        --region "$REGION" \
        --max-results 20 \
        --output table 2>/dev/null || echo "No solutions found"

    echo ""
}

get_solution() {
    local solution_id="$1"

    echo -e "${BLUE}═══ Solution Details ═══${NC}"

    aws partnercentral-selling get-solution \
        --catalog "AWS" \
        --identifier "$solution_id" \
        --region "$REGION" \
        --output json 2>/dev/null | jq '.'

    echo ""
}

associate_solution_to_opportunity() {
    local opp_id="$1"
    local solution_id="$2"

    echo -e "${BLUE}═══ Associating Solution to Opportunity ═══${NC}"

    aws partnercentral-selling associate-opportunity \
        --catalog "AWS" \
        --opportunity-identifier "$opp_id" \
        --related-entity-identifier "$solution_id" \
        --related-entity-type "Solutions" \
        --region "$REGION" \
        --output json 2>/dev/null | jq '.'

    echo ""
}

# ═══════════════════════════════════════════════════════════
# AWS OPPORTUNITY INSIGHTS
# ═══════════════════════════════════════════════════════════

get_aws_opportunity_summary() {
    local catalog="AWS"
    local related_opp_id="$1"

    echo -e "${BLUE}═══ AWS Opportunity Summary ═══${NC}"

    echo "Getting AWS opportunity insights..."
    aws partnercentral-selling get-aws-opportunity-summary \
        --catalog "$catalog" \
        --related-opportunity-identifier "$related_opp_id" \
        --region "$REGION" \
        --output json 2>/dev/null | jq '.' || echo "No AWS opportunity summary available"

    echo ""
}

# ═══════════════════════════════════════════════════════════
# BATCH OPERATIONS
# ═══════════════════════════════════════════════════════════

export_all_opportunities() {
    echo -e "${BLUE}═══ Exporting All Opportunities ═══${NC}"

    local output_file="/tmp/opportunities-export-$(date +%Y%m%d-%H%M%S).json"

    echo "Exporting to: $output_file"
    aws partnercentral-selling list-opportunities \
        --catalog "AWS" \
        --region "$REGION" \
        --max-results 100 \
        --output json > "$output_file" 2>/dev/null || echo "Export failed"

    if [ -f "$output_file" ]; then
        echo -e "${GREEN}✓ Exported $(jq '.OpportunitySummaries | length' "$output_file") opportunities${NC}"
        echo "File: $output_file"
    fi

    echo ""
}

bulk_update_opportunities() {
    echo -e "${BLUE}═══ Bulk Opportunity Updates ═══${NC}"

    echo "This would update multiple opportunities at once"
    echo "(Requires iteration over opportunity list)"

    echo ""
}

# ═══════════════════════════════════════════════════════════
# REPORTING & ANALYTICS
# ═══════════════════════════════════════════════════════════

generate_opportunity_report() {
    echo -e "${BLUE}═══ Opportunity Report ═══${NC}"

    local report_file="/tmp/opportunity-report-$(date +%Y%m%d).md"

    cat > "$report_file" <<EOF
# AWS Partner Central - Opportunity Report
Generated: $(date)
Account: $ACCOUNT_ID

## Summary

EOF

    # Get opportunities and generate report
    aws partnercentral-selling list-opportunities \
        --catalog "AWS" \
        --region "$REGION" \
        --max-results 100 \
        --output json 2>/dev/null | jq -r '
        .OpportunitySummaries | group_by(.LifeCycle.Stage) |
        map({
            stage: .[0].LifeCycle.Stage,
            count: length
        }) |
        .[] |
        "- \(.stage): \(.count) opportunities"
    ' >> "$report_file" 2>/dev/null || echo "No opportunities to report" >> "$report_file"

    echo -e "${GREEN}✓ Report generated: $report_file${NC}"
    cat "$report_file"
    echo ""
}

# ═══════════════════════════════════════════════════════════
# MAIN MENU
# ═══════════════════════════════════════════════════════════

show_menu() {
    cat <<EOF

${BOLD}AWS Partner Central CLI Manager - Main Menu${NC}
══════════════════════════════════════════════════════════

${YELLOW}Account Management:${NC}
  1. Get Partner Profile
  2. Get Alliance Lead Contact
  3. List Connections
  4. List Connection Invitations

${YELLOW}Opportunity Management:${NC}
  5. List Opportunities
  6. Create New Opportunity
  7. Get Opportunity Details (requires ID)
  8. Update Opportunity Stage (requires ID)
  9. Export All Opportunities

${YELLOW}Engagement & Referrals:${NC}
  10. List AWS Referral Invitations
  11. Accept Referral (requires ID)
  12. Reject Referral (requires ID)

${YELLOW}Solution Management:${NC}
  13. List Solutions
  14. Associate Solution to Opportunity (requires IDs)

${YELLOW}Reporting:${NC}
  15. Generate Opportunity Report

${YELLOW}Quick Operations:${NC}
  A. Full Account Overview
  B. Opportunity Dashboard
  Q. Quit

Enter choice:
EOF
}

# Quick operation: Full account overview
full_account_overview() {
    echo -e "${BOLD}${BLUE}Full Account Overview${NC}"
    echo "══════════════════════════════════════════════════════════"

    get_partner_profile
    get_alliance_lead
    list_connections
    list_opportunities
    list_engagement_invitations
    list_solutions
}

# Quick operation: Opportunity dashboard
opportunity_dashboard() {
    echo -e "${BOLD}${BLUE}Opportunity Dashboard${NC}"
    echo "══════════════════════════════════════════════════════════"

    list_opportunities
    generate_opportunity_report
}

# Run based on command line args or interactive mode
if [ $# -gt 0 ]; then
    case "$1" in
        overview|--overview|-o)
            full_account_overview
            ;;
        opportunities|--opportunities|-op)
            opportunity_dashboard
            ;;
        list-opp|--list-opportunities)
            list_opportunities
            ;;
        create-opp|--create-opportunity)
            create_opportunity "${2:-Sample Customer}" "${3:-New Opportunity}"
            ;;
        referrals|--referrals|-r)
            list_engagement_invitations
            ;;
        solutions|--solutions|-s)
            list_solutions
            ;;
        report|--report)
            generate_opportunity_report
            ;;
        export|--export)
            export_all_opportunities
            ;;
        help|--help|-h)
            cat <<EOF
AWS Partner Central CLI Manager

Usage:
  $0 [command]

Commands:
  overview              Full account overview
  opportunities         Opportunity dashboard
  list-opp             List all opportunities
  create-opp           Create new opportunity
  referrals            List AWS referrals
  solutions            List partner solutions
  report               Generate opportunity report
  export               Export opportunities to JSON
  help                 Show this help

Interactive Mode:
  $0                   (no arguments - shows menu)

Examples:
  $0 overview
  $0 create-opp "Acme Corp" "Cloud Migration"
  $0 referrals
EOF
            ;;
        *)
            echo "Unknown command: $1"
            echo "Run '$0 help' for usage"
            exit 1
            ;;
    esac
else
    # Interactive mode
    while true; do
        show_menu
        read -r choice
        case "$choice" in
            1) get_partner_profile ;;
            2) get_alliance_lead ;;
            3) list_connections ;;
            4) list_connection_invitations ;;
            5) list_opportunities ;;
            6)
                read -p "Customer name: " cust_name
                read -p "Opportunity title: " opp_title
                create_opportunity "$cust_name" "$opp_title"
                ;;
            7)
                read -p "Opportunity ID: " opp_id
                get_opportunity "$opp_id"
                ;;
            8)
                read -p "Opportunity ID: " opp_id
                read -p "New stage: " stage
                update_opportunity_stage "$opp_id" "$stage"
                ;;
            9) export_all_opportunities ;;
            10) list_engagement_invitations ;;
            11)
                read -p "Invitation ID: " inv_id
                accept_engagement_invitation "$inv_id"
                ;;
            12)
                read -p "Invitation ID: " inv_id
                read -p "Rejection reason: " reason
                reject_engagement_invitation "$inv_id" "$reason"
                ;;
            13) list_solutions ;;
            14)
                read -p "Opportunity ID: " opp_id
                read -p "Solution ID: " sol_id
                associate_solution_to_opportunity "$opp_id" "$sol_id"
                ;;
            15) generate_opportunity_report ;;
            A|a) full_account_overview ;;
            B|b) opportunity_dashboard ;;
            Q|q) echo "Goodbye!"; exit 0 ;;
            *) echo "Invalid choice" ;;
        esac
        read -p "Press Enter to continue..."
    done
fi
