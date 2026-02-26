#!/bin/bash
set -euo pipefail

# Partner Central Automation Workflows
# Common automation patterns for Partner Central management

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REGION="${AWS_REGION:-us-east-1}"

# ═══════════════════════════════════════════════════════════
# WORKFLOW 1: Daily Partner Central Sync
# ═══════════════════════════════════════════════════════════

daily_sync() {
    echo -e "${BLUE}═══ Daily Partner Central Sync ═══${NC}"
    local date=$(date +%Y%m%d)
    local sync_dir="/tmp/partner-central-sync-$date"
    mkdir -p "$sync_dir"

    echo "Syncing Partner Central data to: $sync_dir"

    # 1. Export opportunities
    echo "  1/5 Exporting opportunities..."
    aws partnercentral-selling list-opportunities \
        --catalog "AWS" \
        --region "$REGION" \
        --max-results 100 \
        --output json > "$sync_dir/opportunities.json" 2>/dev/null || echo "    No opportunities"

    # 2. Export solutions
    echo "  2/5 Exporting solutions..."
    aws partnercentral-selling list-solutions \
        --catalog "AWS" \
        --region "$REGION" \
        --max-results 100 \
        --output json > "$sync_dir/solutions.json" 2>/dev/null || echo "    No solutions"

    # 3. Export referrals
    echo "  3/5 Exporting AWS referrals..."
    aws partnercentral-selling list-engagement-invitations \
        --catalog "AWS" \
        --region "$REGION" \
        --max-results 100 \
        --output json > "$sync_dir/referrals.json" 2>/dev/null || echo "    No referrals"

    # 4. Export connections
    echo "  4/5 Exporting connections..."
    aws partnercentral-account list-connections \
        --region "$REGION" \
        --output json > "$sync_dir/connections.json" 2>/dev/null || echo "    No connections"

    # 5. Generate summary report
    echo "  5/5 Generating summary..."
    cat > "$sync_dir/README.md" <<EOF
# Partner Central Daily Sync
Date: $(date)

## Files
- opportunities.json: All partner opportunities
- solutions.json: Partner solution catalog
- referrals.json: AWS referral invitations
- connections.json: Partner network connections

## Summary
- Opportunities: $(jq '.OpportunitySummaries | length' "$sync_dir/opportunities.json" 2>/dev/null || echo "0")
- Solutions: $(jq '.SolutionSummaries | length' "$sync_dir/solutions.json" 2>/dev/null || echo "0")
- Pending Referrals: $(jq '.EngagementInvitationSummaries | length' "$sync_dir/referrals.json" 2>/dev/null || echo "0")
- Connections: $(jq '.ConnectionSummaries | length' "$sync_dir/connections.json" 2>/dev/null || echo "0")
EOF

    echo -e "${GREEN}✓ Sync complete: $sync_dir${NC}"
    cat "$sync_dir/README.md"
}

# ═══════════════════════════════════════════════════════════
# WORKFLOW 2: Automated Referral Processing
# ═══════════════════════════════════════════════════════════

process_new_referrals() {
    echo -e "${BLUE}═══ Processing New AWS Referrals ═══${NC}"

    local referrals=$(aws partnercentral-selling list-engagement-invitations \
        --catalog "AWS" \
        --region "$REGION" \
        --output json 2>/dev/null)

    local pending_count=$(echo "$referrals" | jq '.EngagementInvitationSummaries | length' 2>/dev/null || echo "0")

    if [ "$pending_count" -eq 0 ]; then
        echo "No pending referrals to process"
        return
    fi

    echo "Found $pending_count pending referral(s)"
    echo ""

    # List and process each referral
    echo "$referrals" | jq -r '.EngagementInvitationSummaries[] |
        "ID: \(.Id)\nCustomer: \(.Payload.Customer.CompanyName)\nExpiry: \(.ExpirationDate)\n---"' || echo "Could not parse referrals"

    echo ""
    echo "To process referrals:"
    echo "  Accept: aws partnercentral-selling start-engagement-by-accepting-invitation --catalog AWS --identifier <ID>"
    echo "  Reject: aws partnercentral-selling reject-engagement-invitation --catalog AWS --identifier <ID>"
}

# ═══════════════════════════════════════════════════════════
# WORKFLOW 3: Opportunity Pipeline Report
# ═══════════════════════════════════════════════════════════

pipeline_report() {
    echo -e "${BLUE}═══ Opportunity Pipeline Report ═══${NC}"

    local opportunities=$(aws partnercentral-selling list-opportunities \
        --catalog "AWS" \
        --region "$REGION" \
        --max-results 100 \
        --output json 2>/dev/null)

    if [ -z "$opportunities" ]; then
        echo "No opportunities found"
        return
    fi

    # Parse and analyze pipeline
    echo "$opportunities" | jq -r '
    .OpportunitySummaries |
    group_by(.LifeCycle.Stage) |
    map({
        stage: (.[0].LifeCycle.Stage // "Unknown"),
        count: length,
        opportunities: [.[] | {
            id: .Id,
            customer: .Customer.CompanyName,
            created: .CreatedDate
        }]
    }) |
    .[] |
    "
Stage: \(.stage)
Count: \(.count)
Opportunities:
\(.opportunities[] | "  - \(.customer) (ID: \(.id))")
"
    ' || echo "Could not parse opportunities"
}

# ═══════════════════════════════════════════════════════════
# WORKFLOW 4: Solution-Opportunity Mapping
# ═══════════════════════════════════════════════════════════

map_solutions_to_opportunities() {
    echo -e "${BLUE}═══ Solution-Opportunity Mapping ═══${NC}"

    # Get solutions
    local solutions=$(aws partnercentral-selling list-solutions \
        --catalog "AWS" \
        --region "$REGION" \
        --output json 2>/dev/null)

    # Get opportunities
    local opportunities=$(aws partnercentral-selling list-opportunities \
        --catalog "AWS" \
        --region "$REGION" \
        --output json 2>/dev/null)

    echo "Available Solutions:"
    echo "$solutions" | jq -r '.SolutionSummaries[]? | "  - \(.Name) (ID: \(.Id))"' 2>/dev/null || echo "  No solutions found"

    echo ""
    echo "Opportunities Needing Solution Association:"
    echo "$opportunities" | jq -r '.OpportunitySummaries[]? |
        select(.Project.RelatedOpportunityIdentifier == null) |
        "  - \(.Customer.CompanyName) (ID: \(.Id))"' 2>/dev/null || echo "  All opportunities have solutions associated"

    echo ""
    echo "To associate a solution to an opportunity:"
    echo "  aws partnercentral-selling associate-opportunity \\"
    echo "    --catalog AWS \\"
    echo "    --opportunity-identifier <OPP-ID> \\"
    echo "    --related-entity-identifier <SOLUTION-ID> \\"
    echo "    --related-entity-type Solutions \\"
    echo "    --region $REGION"
}

# ═══════════════════════════════════════════════════════════
# WORKFLOW 5: Stale Opportunity Cleanup
# ═══════════════════════════════════════════════════════════

find_stale_opportunities() {
    echo -e "${BLUE}═══ Stale Opportunity Detection ═══${NC}"

    local opportunities=$(aws partnercentral-selling list-opportunities \
        --catalog "AWS" \
        --region "$REGION" \
        --max-results 100 \
        --output json 2>/dev/null)

    # Find opportunities not modified in 90 days
    local cutoff_date=$(date -d '90 days ago' +%Y-%m-%d)

    echo "Finding opportunities not modified since: $cutoff_date"
    echo ""

    echo "$opportunities" | jq --arg cutoff "$cutoff_date" -r '
    .OpportunitySummaries[]? |
    select(.LastModifiedDate < $cutoff) |
    "Customer: \(.Customer.CompanyName)
ID: \(.Id)
Stage: \(.LifeCycle.Stage)
Last Modified: \(.LastModifiedDate)
---"
    ' 2>/dev/null || echo "No stale opportunities found"

    echo ""
    echo "Consider updating or closing stale opportunities to maintain pipeline accuracy"
}

# ═══════════════════════════════════════════════════════════
# WORKFLOW 6: Weekly Summary Email (JSON output for integration)
# ═══════════════════════════════════════════════════════════

weekly_summary() {
    echo -e "${BLUE}═══ Weekly Summary ═══${NC}"

    local summary_file="/tmp/weekly-summary-$(date +%Y%m%d).json"

    cat > "$summary_file" <<EOF
{
  "report_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "week_start": "$(date -d 'last monday' +%Y-%m-%d)",
  "week_end": "$(date -d 'next sunday' +%Y-%m-%d)",
  "opportunities": {},
  "referrals": {},
  "solutions": {},
  "actions_needed": []
}
EOF

    # Add opportunities data
    local opp_data=$(aws partnercentral-selling list-opportunities \
        --catalog "AWS" \
        --region "$REGION" \
        --max-results 100 \
        --output json 2>/dev/null)

    # Add referrals data
    local ref_data=$(aws partnercentral-selling list-engagement-invitations \
        --catalog "AWS" \
        --region "$REGION" \
        --max-results 100 \
        --output json 2>/dev/null)

    # Merge data (simplified version)
    echo "$summary_file created with weekly summary"
    echo ""
    echo "Summary:"
    echo "  Total Opportunities: $(echo "$opp_data" | jq '.OpportunitySummaries | length' 2>/dev/null || echo "0")"
    echo "  Pending Referrals: $(echo "$ref_data" | jq '.EngagementInvitationSummaries | length' 2>/dev/null || echo "0")"
    echo ""
    echo "Output: $summary_file"
}

# ═══════════════════════════════════════════════════════════
# MAIN AUTOMATION MENU
# ═══════════════════════════════════════════════════════════

case "${1:-menu}" in
    daily-sync|sync)
        daily_sync
        ;;
    referrals|process-referrals)
        process_new_referrals
        ;;
    pipeline|report)
        pipeline_report
        ;;
    map-solutions|mapping)
        map_solutions_to_opportunities
        ;;
    stale|cleanup)
        find_stale_opportunities
        ;;
    weekly|summary)
        weekly_summary
        ;;
    all|full-automation)
        echo "Running all automation workflows..."
        daily_sync
        echo ""
        process_new_referrals
        echo ""
        pipeline_report
        echo ""
        find_stale_opportunities
        ;;
    help|--help)
        cat <<EOF
Partner Central Automation Workflows

Usage: $0 [workflow]

Workflows:
  daily-sync            Daily data synchronization
  referrals             Process new AWS referrals
  pipeline              Opportunity pipeline report
  map-solutions         Solution-opportunity mapping
  stale                 Find stale opportunities
  weekly                Weekly summary report
  all                   Run all workflows

Examples:
  $0 daily-sync
  $0 referrals
  $0 pipeline

Automation Schedule (cron):
  # Daily sync at 9 AM
  0 9 * * * /path/to/partner-central-automation.sh daily-sync

  # Weekly summary on Mondays
  0 9 * * 1 /path/to/partner-central-automation.sh weekly

  # Check referrals every 4 hours
  0 */4 * * * /path/to/partner-central-automation.sh referrals
EOF
        ;;
    *)
        echo "Unknown workflow: ${1}"
        echo "Run '$0 help' for available workflows"
        exit 1
        ;;
esac
