# Ansible Configuration

Use Ansible for:
- Build host bootstrap (docker, toolchains, awscli, terraform)
- Runtime configuration (self-hosted runners, observability agents)
- Controlled service deployments (if not using GitOps)

## Directory Structure

```
ansible/
├── inventories/       # Environment-specific inventory files
│   ├── dev.ini
│   └── prod.ini
├── group_vars/        # Variables for inventory groups
│   └── all.yml
├── playbooks/         # Top-level playbooks
│   ├── site.yml       # Main entry point
│   ├── bootstrap-build-host.yml
│   └── deploy-services.yml
└── roles/             # Reusable roles
    ├── common/        # Base packages, configs
    ├── build-host/    # Dev tooling, CI runners
    ├── observability-agent/  # CloudWatch, OTEL
    └── github-runner/ # Self-hosted runner setup
```

## Quick Start

```bash
# Install Ansible
pip install ansible boto3 botocore

# Run against dev environment
ansible-playbook -i inventories/dev.ini playbooks/site.yml

# Bootstrap a build host
ansible-playbook -i inventories/dev.ini playbooks/bootstrap-build-host.yml

# Deploy services only
ansible-playbook -i inventories/dev.ini playbooks/deploy-services.yml
```

## Requirements

- Ansible 2.14+
- Python 3.9+
- AWS credentials configured
- SSH access to target hosts

## Tags

Use tags to run specific parts:

```bash
# Only common setup
ansible-playbook -i inventories/dev.ini playbooks/site.yml --tags common

# Skip slow tasks
ansible-playbook -i inventories/dev.ini playbooks/site.yml --skip-tags slow
```
