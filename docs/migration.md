# Migration Guide: Monolithic `account` to Single-Resource `aws-account`

This document outlines the migration from the monolithic `account` component to the new single-resource `aws-account` component.

## Overview

The previous `account` component created all AWS Organizations resources (organization, OUs, accounts, SCPs) in a single Terraform state. The new `aws-account` component follows the single-resource pattern - it manages exactly one AWS account per component instance.

### Why Migrate?

| Aspect | Old `account` Component | New `aws-account` Component |
|--------|-------------------------|----------------------------|
| **Scope** | Entire organization hierarchy | Single AWS account |
| **State** | All resources in one state | Independent state per account |
| **Lifecycle** | Changes affect all accounts | Changes isolated to one account |
| **Risk** | High blast radius | Minimal blast radius |
| **Flexibility** | Monolithic configuration | Granular control |

### New Component Suite

The monolithic `account` component is replaced by these single-resource components:

| Component | Purpose |
|-----------|---------|
| `aws-organization` | Creates/imports the AWS Organization |
| `aws-organizational-unit` | Creates/imports a single OU |
| `aws-account` | Creates/imports a single AWS Account (this component) |
| `aws-account-settings` | Configures account settings (IAM alias, S3 block, EBS encryption) |
| `aws-scp` | Creates/imports Service Control Policies |

---

## Migration Steps

### Phase 1: Prepare Stack Configuration

#### 1.1 Create Catalog Defaults

Create a defaults file for consistent configuration:

```yaml
# stacks/catalog/aws-account/defaults.yaml
components:
  terraform:
    aws-account/defaults:
      metadata:
        component: aws-account
        type: abstract
      vars:
        enabled: true
        iam_user_access_to_billing: DENY
        close_on_deletion: false
```

#### 1.2 Define Account Components

In your root account's global stack (e.g., `stacks/orgs/<namespace>/core/root/global-region.yaml`):

```yaml
import:
  - catalog/aws-account/defaults

components:
  terraform:
    # Example: Core OU Accounts
    aws-account/core-security:
      metadata:
        component: aws-account
        inherits:
          - aws-account/defaults
      vars:
        name: core-security
        account_email: "aws+<namespace>-core-security@example.com"
        parent_id: "ou-xxxx-xxxxxxxx"  # Or use remote state reference
        import_account_id: "<account-id>"

    aws-account/core-network:
      metadata:
        component: aws-account
        inherits:
          - aws-account/defaults
      vars:
        name: core-network
        account_email: "aws+<namespace>-core-network@example.com"
        parent_id: "ou-xxxx-xxxxxxxx"
        import_account_id: "<account-id>"

    # Repeat for all accounts...
```

### Phase 2: Collect Resource IDs

Before running imports, collect the existing account IDs from your AWS Organization.

#### 2.1 Get Account IDs

```bash
# List all accounts with their IDs
aws organizations list-accounts \
  --query 'Accounts[*].[Name,Id]' --output table

# Get OU IDs (for parent_id)
aws organizations list-roots --query 'Roots[0].Id' --output text
aws organizations list-organizational-units-for-parent \
  --parent-id r-xxxx \
  --query 'OrganizationalUnits[*].[Name,Id]' --output table
```

#### 2.2 Update Stack Configuration

Add the `import_account_id` for each account in your stack configuration.

### Phase 3: Import Accounts

Run the import for each account:

```bash
# Import each account
atmos terraform apply aws-account/core-security -s <namespace>-gbl-root
atmos terraform apply aws-account/core-network -s <namespace>-gbl-root
atmos terraform apply aws-account/core-identity -s <namespace>-gbl-root
# ... repeat for all accounts
```

The `import` block in `imports.tf` will automatically import the existing account when `import_account_id` is set.

> **Note:** If you don't want the import functionality, you can exclude `imports.tf` when vendoring the component.

### Phase 4: Remove Old Component State

After successful import, both the old `account` component and new `aws-account` components will reference the same AWS resources. You must remove the old component's state **without destroying** the resources.

#### 4.1 Remove Resources from Old State

> [!CAUTION]
> **CRITICAL:** Use `terraform state rm` to remove resources from state without destroying them.
> Running `terraform destroy` will **permanently delete** your AWS accounts!

```bash
# List all resources in old account component state
atmos terraform state list account -s <namespace>-gbl-root

# Remove account resources from old state (DO NOT use terraform destroy!)
atmos terraform state rm account -s <namespace>-gbl-root \
  'aws_organizations_account.organizational_units_accounts["core-security"]'

atmos terraform state rm account -s <namespace>-gbl-root \
  'aws_organizations_account.organizational_units_accounts["core-network"]'

# Repeat for all accounts that were migrated
```

#### 4.2 Remove Old Component from Stack

After state is cleared, remove the old `account` component import from your stack:

```yaml
import:
  # Remove this line:
  # - catalog/account
```

### Phase 5: Update Dependent Components

Components that reference the old `account` component via remote-state need to be updated.

#### 5.1 Identify Dependencies

Search for components using `account` remote-state:

```bash
grep -r "component.*account" stacks/
grep -r "remote-state.*account" components/terraform/
```

#### 5.2 Update Remote State References

**Old pattern:**
```hcl
module "account" {
  source    = "cloudposse/stack-config/yaml//modules/remote-state"
  component = "account"
  # ...
}

locals {
  account_id = module.account.outputs.account_names_account_ids["core-security"]
}
```

**New pattern:**
```hcl
module "account" {
  source    = "cloudposse/stack-config/yaml//modules/remote-state"
  component = "aws-account/core-security"
  # ...
}

locals {
  account_id = module.account.outputs.account_id
}
```

---

## Rollback Plan

If issues occur during migration:

1. **Before state removal:** Revert the stack configuration changes
2. **After state removal:** Re-import resources into the old `account` component:
   ```bash
   atmos terraform import account -s <namespace>-gbl-root \
     'aws_organizations_account.organizational_units_accounts["core-security"]' '<account-id>'
   ```

---

## Post-Migration Verification

After migration, verify:

1. **Accounts exist:** `aws organizations list-accounts`
2. **No drift:** Run `atmos terraform plan` on all new `aws-account/*` components
3. **Dependent components work:** Test components that reference account outputs

```bash
# Verify no changes planned for each account
atmos terraform plan aws-account/core-security -s <namespace>-gbl-root
atmos terraform plan aws-account/core-network -s <namespace>-gbl-root
# ...
```

---

## Troubleshooting

### Import Block Not Working

Ensure you're using OpenTofu >= 1.7.0 or Terraform >= 1.7.0 (required for `for_each` in `import` blocks).

> **Note:** Basic import blocks are available in Terraform 1.5+, but `for_each` support requires 1.7+.

If you excluded `imports.tf` when vendoring, the import block won't be available. Either:
- Include `imports.tf` in your vendored component
- Use `terraform import` manually:
  ```bash
  atmos terraform import aws-account/core-security -s <namespace>-gbl-root \
    'aws_organizations_account.this[0]' '<account-id>'
  ```

### Stale State Errors

If you see errors about missing providers or modules in state, remove stale entries:

```bash
# Check what's in the state
atmos terraform state list aws-account/core-security -s <namespace>-gbl-root

# Remove any stale module entries (keep aws_organizations_account.this[0])
atmos terraform state rm aws-account/core-security -s <namespace>-gbl-root \
  'module.some_old_module[0].data.something'
```

### Account Already Managed Error

If Terraform reports the account is already managed, ensure you removed it from the old `account` component state first (Phase 4.1).

---

## References

- [OpenTofu Import Blocks](https://opentofu.org/docs/language/import/)
- [Atmos Documentation](https://atmos.tools/)
- [AWS Organizations API](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_accounts.html)
