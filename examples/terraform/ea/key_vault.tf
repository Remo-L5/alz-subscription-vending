# Key Vault
#
# Key Vaults are provisioned with the azapi provider because the target
# subscription ids are not known at plan time (they are created by the
# lz_vending module during apply). Using azapi lets the parent_id be derived
# from the module outputs after the subscription/resource group exist.
#
# One Key Vault is created per environment/location:
#   - Standard SKU
#   - Public network access disabled (deny by default)
#   - RBAC authorization enabled
#   - Enabled for ARM template deployments, VM deployments and disk encryption
# A private endpoint is deployed into the 'private_endpoint' subnet so the
# vault is only reachable over private networking.

# Azure Verified Module (utility) that resolves built-in role definition names
# to their UUIDs, so we don't hardcode role definition GUIDs.
module "role_definitions" {
  source  = "Azure/avm-utl-roledefinitions/azure"
  version = "0.3.0"

  enable_telemetry = false
}

resource "azapi_resource" "key_vault" {
  for_each = local.key_vaults

  type      = "Microsoft.KeyVault/vaults@2024-11-01"
  name      = each.value.name
  location  = each.value.location
  parent_id = module.lz_vending[each.value.environment].resource_group_resource_ids[each.value.resource_group_key]

  body = {
    properties = {
      tenantId = data.azurerm_client_config.current.tenant_id
      sku = {
        family = "A"
        name   = "standard"
      }
      enableRbacAuthorization      = true
      enabledForTemplateDeployment = true
      enabledForDeployment         = true
      enabledForDiskEncryption     = true
      enableSoftDelete             = true
      softDeleteRetentionInDays    = 30
      enablePurgeProtection        = true
      publicNetworkAccess          = "Disabled"
      networkAcls = {
        bypass        = "AzureServices"
        defaultAction = "Deny"
      }
    }
  }

  tags = local.subscriptions_to_provision[each.value.environment].tags
}

resource "azapi_resource" "key_vault_private_endpoint" {
  for_each = local.key_vaults

  type      = "Microsoft.Network/privateEndpoints@2024-05-01"
  name      = each.value.private_endpoint_name
  location  = each.value.location
  parent_id = module.lz_vending[each.value.environment].resource_group_resource_ids[each.value.resource_group_key]

  body = {
    properties = {
      subnet = {
        id = "${module.lz_vending[each.value.environment].virtual_network_resource_ids[each.value.vnet_key]}/subnets/${each.value.subnet_name}"
      }
      privateLinkServiceConnections = [
        {
          name = "plsc-${each.value.name}"
          properties = {
            privateLinkServiceId = azapi_resource.key_vault[each.key].id
            groupIds             = ["vault"]
          }
        }
      ]
    }
  }

  tags = local.subscriptions_to_provision[each.value.environment].tags
}

# Role assignments granting each user-assigned managed identity access to the
# Key Vault via RBAC. The plan and app identities receive the User roles
# (crypto/secret/certificate) and the apply identity receives the Officer roles.

# A stable GUID is generated once per role assignment. The keepers tie the GUID
# to the assignment identity so it is only regenerated if the scope, principal
# or role definition changes - not on every run.
resource "random_uuid" "key_vault_role_assignment" {
  for_each = local.key_vault_role_assignments

  keepers = {
    kv_key             = each.value.kv_key
    umi_key            = each.value.umi_key
    role_definition_id = each.value.role_definition_id
  }
}

resource "azapi_resource" "key_vault_role_assignment" {
  for_each = local.key_vault_role_assignments

  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = random_uuid.key_vault_role_assignment[each.key].result
  parent_id = azapi_resource.key_vault[each.value.kv_key].id

  body = {
    properties = {
      roleDefinitionId = "${module.lz_vending[each.value.environment].subscription_resource_id}/providers/Microsoft.Authorization/roleDefinitions/${each.value.role_definition_id}"
      principalId      = module.lz_vending[each.value.environment].umi_principal_ids[each.value.umi_key]
      principalType    = "ServicePrincipal"
    }
  }
}
