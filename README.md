# Azure Landing Zone Subscription Vending

This repository provides Terraform modules and examples for automated subscription provisioning and management within Azure Landing Zones using Microsoft Customer Agreement (MCA) billing. It demonstrates how to create and configure Azure subscriptions with standardized networking, security, and governance configurations.

## Overview

The subscription vending solution automates:
- **Subscription Creation**: Provisions new Azure subscriptions under MCA billing
- **Network Configuration**: Sets up hub-spoke network topology with proper routing and security
- **Identity Management**: Creates User Managed Identities for secure workload access
- **Azure DevOps Integration**: Configures service connections with federated credentials
- **Governance**: Applies consistent tagging, RBAC, and management group placement

## Architecture

This solution creates a standardized landing zone pattern with:
- Hub-spoke network topology with Azure Firewall integration
- Environment-specific subscriptions (test/prod)
- User Managed Identities for CI/CD pipelines
- Federated identity credentials for secure Azure DevOps integration
- Standardized resource groups and naming conventions

## Prerequisites

Before using this repository, ensure you have:

### Azure Requirements
- **Billing Account Access**: Contributor or Billing Profile Contributor role on the MCA billing account
- **Management Group Permissions**: Management Group Contributor role for subscription placement
- **Hub Network**: Existing hub virtual network with Azure Firewall deployed
- **Azure AD Permissions**: Application Administrator or Global Administrator for service principal creation

### Tools Required
- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) >= 2.0
- [Azure DevOps CLI](https://docs.microsoft.com/en-us/azure/devops/cli/) (optional)

### Azure DevOps Setup
- Azure DevOps organization with project access
- Personal Access Token (PAT) with appropriate permissions
- Key Vault to store the PAT securely

## Getting Started with Microsoft Customer Agreement

### Step 1: Gather MCA Billing Information

First, identify your MCA billing account and profile details:

```bash
# List billing accounts
az billing account list --query "[].{Name:displayName, ID:name}"

# List billing profiles for your account
az billing profile list --account-name "YOUR_BILLING_ACCOUNT_ID" --query "[].{Name:displayName, ID:name}"
```

### Step 2: Configure Variables

Create a `terraform.tfvars` file based on the example below:

```hcl
# Application Information
application_name       = "My Enterprise App"
application_short_name = "myapp"
location              = "westus2"

# Billing Configuration (MCA)
billing_account_id  = "your-billing-account-id"
billing_profile_id  = "your-billing-profile-id"
org_code           = "MYORG"

# Management Group
management_group_name = "alz-landingzones"

# Network Configuration
spoke_vnet_address_space     = "10.100.0.0/16"
hub_network_id              = "/subscriptions/hub-sub-id/resourceGroups/rg-hub/providers/Microsoft.Network/virtualNetworks/vnet-hub"
hub_fw_ip                   = "10.0.1.4"
hub_network_address_prefix  = "10.0.0.0/16"

# Identity and Access
subscription_owner_object_id          = "user-object-id"
subscription_developer_group_object_id = "group-object-id"

# Azure DevOps Integration
azure_devops_organization_url = "https://dev.azure.com/your-org"
azure_devops_project_name    = "your-project"
key_vault_name               = "kv-shared-secrets"
key_vault_rg                = "rg-shared-secrets"
pat_secret_name             = "ado-pat"
```

### Step 3: Deploy the Infrastructure

1. **Initialize Terraform**:
   ```bash
   cd examples/mca
   terraform init
   ```

2. **Plan the deployment**:
   ```bash
   terraform plan
   ```

3. **Apply the configuration**:
   ```bash
   terraform apply
   ```

## What Gets Created

### Per Environment (Test/Prod)

For each environment, the solution creates:

#### Subscription Resources
- New Azure subscription under the specified invoice section
- Management group association for governance
- Role assignments for subscription management

#### Resource Groups
- `rg-{app}-{env}-{location}-network-01`: Network resources
- `rg-{app}-{env}-{location}-identity-01`: Identity and security resources  
- `rg-{app}-{env}-{location}-app-01`: Application resources

#### Network Infrastructure
- Virtual network with hub peering
- Subnets for applications and private endpoints
- Network security groups with appropriate rules
- Route tables directing traffic through hub firewall

#### Identity and Security
- User Managed Identities for CI/CD operations:
  - Plan identity (Reader permissions)
  - Apply identity (Contributor permissions)
  - Application identity (custom permissions)
- Federated identity credentials for Azure DevOps

#### Azure DevOps Integration
- Service connections with workload identity federation
- Secure authentication without storing secrets

## Module Structure

```
modules/
├── azure_devops_svc_conn/     # Azure DevOps service connection module
│   ├── main.tf                # Service endpoint and federated credential resources
│   ├── data.tf                # Data sources for Azure DevOps project
│   └── variables.tf           # Input variables
examples/
├── mca/                       # Microsoft Customer Agreement example
│   ├── main.tf                # Main configuration
│   ├── locals.tf              # Local values and computed data
│   ├── variables.*.tf         # Variable definitions by category
│   └── terraform.tf           # Provider configurations
```

## Configuration Details

### Billing Configuration

The example creates an invoice section under your MCA billing profile:
- **Invoice Section Name**: `{org_code}-{application-name}` (normalized)
- **Display Name**: `{org_code} - {application_name}`
- Used for cost tracking and billing organization

### Network Security

Each spoke network includes:
- **Default Subnet**: For application workloads
- **Private Endpoint Subnet**: For secure service connections
- **Route Table**: Directs traffic through hub firewall (0.0.0.0/0 → hub_fw_ip)
- **NSG Rules**: Allow spoke-to-hub and hub-to-spoke communication

### Identity Federation

The solution creates secure, secret-free CI/CD integration:
- User Managed Identities with appropriate RBAC
- Federated credentials linked to Azure DevOps service connections
- Workload Identity Federation for secure authentication

## Customization

### Adding Environments

To add additional environments, modify the `locals.tf`:

```hcl
locals {
  environments = [
    "dev",    # Add development environment
    "test",
    "uat",    # Add user acceptance testing
    "prod"
  ]
}
```

### Custom Resource Groups

Extend the resource group configuration in `main.tf`:

```hcl
resource_groups = {
  vnetrg = {
    name     = each.value.network_rg
    location = var.location
  }
  mainrg = {
    name     = each.value.application_rg
    location = var.location
  }
  identityrg = {
    name     = each.value.identity_rg
    location = var.location
  }
  # Add custom resource groups
  datarg = {
    name     = "rg-${var.application_short_name}-${each.value.environment}-data-01"
    location = var.location
  }
}
```

### Additional Role Assignments

Add more role assignments in the `role_assignments` block:

```hcl
role_assignments = {
  # Existing assignments...
  
  data_engineers = {
    principal_id   = var.data_engineer_group_object_id
    definition     = "Storage Blob Data Contributor"
    relative_scope = "/resourceGroups/rg-${var.application_short_name}-${each.value.environment}-data-01"
    principal_type = "Group"
  }
}
```

## Troubleshooting

### Common Issues

1. **Billing Account Access**: Ensure you have appropriate permissions on the billing account
2. **Management Group Placement**: Verify the management group exists and you have contributor access
3. **Network Peering**: Check that hub network resource ID is correct and accessible
4. **Azure DevOps PAT**: Ensure the PAT has sufficient permissions and is stored in Key Vault

### Validation Commands

```bash
# Check billing account access
az billing account list

# Verify management group
az account management-group show --name "alz-landingzones"

# Test hub network connectivity
az network vnet show --ids "/subscriptions/hub-sub-id/resourceGroups/rg-hub/providers/Microsoft.Network/virtualNetworks/vnet-hub"
```

## Security Considerations

- Use User Managed Identities instead of service principals where possible
- Store sensitive values like PATs in Azure Key Vault
- Implement least-privilege access with conditional role assignments
- Enable audit logging on all subscriptions
- Use federated credentials to eliminate stored secrets

## Contributing

When contributing to this repository:
1. Follow Terraform best practices and formatting
2. Update documentation for any new variables or resources
3. Test changes in a non-production environment
4. Ensure compliance with your organization's security policies

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.