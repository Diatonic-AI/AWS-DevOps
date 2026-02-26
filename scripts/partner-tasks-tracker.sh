#!/bin/bash

# Partner Central Tasks Interactive Tracker
# Run this script to track your progress on the 17 Partner Central tasks

TASKS_FILE="$HOME/.partner-central-tasks.json"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Initialize tasks file if it doesn't exist
if [ ! -f "$TASKS_FILE" ]; then
    cat > "$TASKS_FILE" <<'EOF'
{
  "tasks": {
    "1": {"name": "Schedule migration to Partner Central", "time": "<4 hours", "completed": false, "priority": "MEDIUM"},
    "2": {"name": "Create first Partner Originated opportunity", "time": ">30 min", "completed": false, "priority": "LOW"},
    "3": {"name": "Map alliance team to IAM roles", "time": "<30 min", "completed": false, "priority": "HIGH"},
    "4": {"name": "Map ACE users to IAM roles", "time": "<5 min", "completed": false, "priority": "HIGH"},
    "5": {"name": "Assign user role", "time": "<5 min", "completed": false, "priority": "HIGH"},
    "6": {"name": "Create IAM Roles", "time": "<30 min", "completed": true, "priority": "HIGH"},
    "7": {"name": "Create AWS Marketplace listing", "time": "5 min", "completed": false, "priority": "LOW"},
    "8": {"name": "Pay APN fee", "time": ">30 min", "completed": false, "priority": "MEDIUM"},
    "9": {"name": "Build managed services solution", "time": "<10 min", "completed": false, "priority": "LOW"},
    "10": {"name": "Update company profile: Tech team size", "time": "<5 min", "completed": false, "priority": "LOW"},
    "11": {"name": "Update company profile: Marketing team size", "time": "<5 min", "completed": false, "priority": "LOW"},
    "12": {"name": "Invite users to Partner Central", "time": "<5 min", "completed": false, "priority": "HIGH"},
    "13": {"name": "Update company profile: Sales team size", "time": "<5 min", "completed": false, "priority": "LOW"},
    "14": {"name": "Build first software solution", "time": ">30 min", "completed": false, "priority": "MEDIUM"},
    "15": {"name": "Assign cloud admin", "time": "<5 min", "completed": false, "priority": "HIGH"},
    "16": {"name": "Learn AWS Marketplace benefits", "time": "<30 min", "completed": false, "priority": "LOW"},
    "17": {"name": "Build services solution", "time": "<10 min", "completed": false, "priority": "LOW"}
  }
}
EOF
fi

# Function to display task list
show_tasks() {
    local filter=$1
    echo -e "${BOLD}${BLUE}AWS Partner Central Tasks${NC}"
    echo "════════════════════════════════════════════════════════════════"

    local completed=0
    local total=17

    # Display tasks
    for i in {1..17}; do
        local task=$(jq -r ".tasks.\"$i\"" "$TASKS_FILE")
        local name=$(echo "$task" | jq -r '.name')
        local time=$(echo "$task" | jq -r '.time')
        local is_completed=$(echo "$task" | jq -r '.completed')
        local priority=$(echo "$task" | jq -r '.priority')

        # Skip if filtering
        if [ ! -z "$filter" ]; then
            if [ "$filter" = "completed" ] && [ "$is_completed" = "false" ]; then
                continue
            fi
            if [ "$filter" = "pending" ] && [ "$is_completed" = "true" ]; then
                continue
            fi
            if [ "$filter" = "high" ] && [ "$priority" != "HIGH" ]; then
                continue
            fi
        fi

        # Set color based on priority and completion
        local color=$NC
        if [ "$is_completed" = "true" ]; then
            color=$GREEN
            symbol="✓"
            completed=$((completed + 1))
        else
            symbol="□"
            case "$priority" in
                HIGH) color=$RED ;;
                MEDIUM) color=$YELLOW ;;
                LOW) color=$NC ;;
            esac
        fi

        printf "${color}[%s] Task %2d: %-45s %10s %s${NC}\n" \
            "$symbol" "$i" "$name" "$time" "($priority)"
    done

    echo "════════════════════════════════════════════════════════════════"
    echo -e "${GREEN}Completed: $completed / $total tasks${NC}"

    local percent=$((completed * 100 / total))
    echo -e "Progress: ${GREEN}$percent%${NC}"

    if [ $completed -eq $total ]; then
        echo ""
        echo -e "${GREEN}${BOLD}🎉 All tasks completed! Your Partner Central setup is complete!${NC}"
    fi
}

# Function to mark task as complete
complete_task() {
    local task_num=$1

    if [ -z "$task_num" ] || [ "$task_num" -lt 1 ] || [ "$task_num" -gt 17 ]; then
        echo -e "${RED}Invalid task number. Use 1-17.${NC}"
        return
    fi

    jq ".tasks.\"$task_num\".completed = true" "$TASKS_FILE" > /tmp/tasks.json && \
        mv /tmp/tasks.json "$TASKS_FILE"

    local task_name=$(jq -r ".tasks.\"$task_num\".name" "$TASKS_FILE")
    echo -e "${GREEN}✓ Marked task $task_num as completed: $task_name${NC}"
}

# Function to mark task as incomplete
uncomplete_task() {
    local task_num=$1

    if [ -z "$task_num" ] || [ "$task_num" -lt 1 ] || [ "$task_num" -gt 17 ]; then
        echo -e "${RED}Invalid task number. Use 1-17.${NC}"
        return
    fi

    jq ".tasks.\"$task_num\".completed = false" "$TASKS_FILE" > /tmp/tasks.json && \
        mv /tmp/tasks.json "$TASKS_FILE"

    local task_name=$(jq -r ".tasks.\"$task_num\".name" "$TASKS_FILE")
    echo -e "${YELLOW}□ Marked task $task_num as incomplete: $task_name${NC}"
}

# Function to show task details
show_task_details() {
    local task_num=$1

    case $task_num in
        1) cat <<EOF
Task 1: Schedule Migration to Partner Central in AWS Console
──────────────────────────────────────────────────────────────
Time: <4 hours (mostly automated by AWS)
Priority: MEDIUM

Steps:
1. Log into https://partnercentral.aws.amazon.com/
2. Look for migration banner at top of page
3. Click "Schedule Migration"
4. Select a maintenance window (suggest off-hours)
5. Review migration checklist
6. Click "Confirm Migration Schedule"

Note: AWS handles most of the migration automatically.
EOF
            ;;
        2) cat <<EOF
Task 2: Create First Partner Originated (PO) Opportunity
──────────────────────────────────────────────────────────────
Time: >30 minutes
Priority: LOW

Steps:
1. Opportunities > Create Opportunity
2. Select "Partner Originated (PO)"
3. Fill in:
   - Customer name and AWS account
   - Expected MRR
   - Close date
   - AWS products/services
   - Link to solution
4. Submit

Benefits: Deal protection, co-selling eligibility, AWS support
EOF
            ;;
        3) cat <<EOF
Task 3: Map Alliance Team to IAM Roles
──────────────────────────────────────────────────────────────
Time: <30 minutes
Priority: HIGH

Steps:
1. Go to https://partnercentral.aws.amazon.com/
2. Settings > Team Management > Alliance Team
3. Click "Add IAM Role"
4. Enter: arn:aws:iam::313476888312:role/AWSPartnerAllianceAccess
5. Save

ARN: arn:aws:iam::313476888312:role/AWSPartnerAllianceAccess
EOF
            ;;
        4) cat <<EOF
Task 4: Map ACE Users to IAM Roles
──────────────────────────────────────────────────────────────
Time: <5 minutes
Priority: HIGH

Steps:
1. Settings > Team Management > ACE Users
2. Click "Add IAM Role"
3. Enter: arn:aws:iam::313476888312:role/AWSPartnerACEAccess
4. Save

ARN: arn:aws:iam::313476888312:role/AWSPartnerACEAccess
EOF
            ;;
        5) cat <<EOF
Task 5: Assign User Role
──────────────────────────────────────────────────────────────
Time: <5 minutes
Priority: HIGH

Steps:
1. Settings > Users
2. Find Drew Fortini
3. Click "Edit"
4. Assign role: "Account Administrator" or "Solution Manager"
5. Save
EOF
            ;;
        6) cat <<EOF
Task 6: Create IAM Roles
──────────────────────────────────────────────────────────────
Time: <30 minutes
Priority: HIGH
Status: ✓ COMPLETED AUTOMATICALLY

Roles created:
- arn:aws:iam::313476888312:role/AWSPartnerCentralAccess
- arn:aws:iam::313476888312:role/AWSPartnerACEAccess
- arn:aws:iam::313476888312:role/AWSPartnerAllianceAccess

These roles were created by the automated setup script.
EOF
            ;;
        14) cat <<EOF
Task 14: Build First Software Solution
──────────────────────────────────────────────────────────────
Time: >30 minutes
Priority: MEDIUM

RECOMMENDED SOLUTION: Diatonic AI Nexus Workbench

Steps:
1. Solutions > Create Solution
2. Type: Software Solution
3. Fill in:
   - Name: "Diatonic AI Nexus Workbench"
   - Category: AI/ML, Container Management
   - AWS Services: ECR, ECS, Lambda, API Gateway, DynamoDB, Cognito
   - Builder Account: 916873234430
4. Upload:
   - Architecture diagram
   - CloudFormation/Terraform templates (from infrastructure/terraform/core/)
   - README and deployment guide
5. Submit for Review

Resources in your repo:
- apps/diatonic-ai-workbench/ (application code)
- infrastructure/terraform/core/ (infrastructure as code)
EOF
            ;;
        *) echo "No detailed help available for task $task_num" ;;
    esac
}

# Main menu
case "${1:-}" in
    list|"")
        show_tasks
        ;;
    pending)
        show_tasks pending
        ;;
    completed)
        show_tasks completed
        ;;
    high)
        echo -e "${RED}HIGH PRIORITY TASKS:${NC}"
        show_tasks high
        ;;
    complete)
        complete_task "$2"
        echo ""
        show_tasks
        ;;
    uncomplete)
        uncomplete_task "$2"
        echo ""
        show_tasks
        ;;
    details|help)
        if [ -z "$2" ]; then
            echo "Usage: $0 details <task_number>"
        else
            show_task_details "$2"
        fi
        ;;
    reset)
        rm -f "$TASKS_FILE"
        echo -e "${YELLOW}Tasks reset. Run again to see fresh task list.${NC}"
        ;;
    *)
        cat <<EOF
AWS Partner Central Tasks Tracker

Usage:
  $0                    - Show all tasks
  $0 list              - Show all tasks
  $0 pending           - Show only pending tasks
  $0 completed         - Show only completed tasks
  $0 high              - Show only high priority tasks
  $0 complete <num>    - Mark task as completed
  $0 uncomplete <num>  - Mark task as incomplete
  $0 details <num>     - Show detailed help for a task
  $0 reset             - Reset all tasks to incomplete

Examples:
  $0 complete 3        - Mark task 3 as completed
  $0 details 14        - Show help for task 14
  $0 high              - Show high priority tasks only
EOF
        ;;
esac
