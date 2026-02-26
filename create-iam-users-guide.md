# IAM User Creation Guide

## For Account 824156498500 (Diatonic Online)
1. Login as root to account 824
2. Go to IAM → Users → Create User
3. Username: `dfortini-admin-824`
4. Enable console access + programmatic access
5. Attach policy: `AdministratorAccess`
6. Download credentials and configure profile:
   ```bash
   aws configure --profile dfortini-824
   ```

## For Account 842990485193 (Diatonic AI)
1. Login as root to account 842
2. Go to IAM → Users → Create User
3. Username: `dfortini-admin-842`
4. Enable console access + programmatic access
5. Attach policy: `AdministratorAccess`
6. Download credentials and configure profile:
   ```bash
   aws configure --profile dfortini-842
   ```

## Test Access
```bash
aws sts get-caller-identity --profile dfortini-824
aws sts get-caller-identity --profile dfortini-842
```
