module "ip_calc" {
  source  = "Azure/avm-utl-network-ip-addresses/azurerm"
  version = "0.1.0"

  for_each = local.address_spaces_required

  address_space = each.value
  address_prefixes = {
    "default"          = 28
    "private_endpoint" = 28
  }
}

resource "azapi_resource" "invoice_section" {
  type      = "Microsoft.Billing/billingAccounts/billingProfiles/invoiceSections@2024-04-01"
  name      = local.invoice_section_name
  parent_id = "/providers/Microsoft.Billing/billingAccounts/${var.billing_account_id}/billingProfiles/${var.billing_profile_id}"

  body = {
    properties = {
      displayName = local.invoice_section_display_name
    }
  }
}

module "lz_vending" {
  source  = "Azure/lz-vending/azurerm"
  version = "5.1.2" # change this to your desired version, https://www.terraform.io/language/expressions/version-constraints
  # Set the default location for resources
  for_each = local.subscriptions_to_provision

  location = var.location

  # subscription variables
  subscription_update_existing = false
  subscription_alias_enabled = true
  subscription_billing_scope = azapi_resource.invoice_section.id
  subscription_display_name  = "${upper(var.application_name)} ${upper(each.value.environment)}"
  subscription_alias_name    = "${var.application_short_name}-${each.value.environment}"
  subscription_workload      = "Production"

  subscription_register_resource_providers_enabled = true
  subscription_register_resource_providers_and_features = var.subscription_resource_providers

  # management group association variables
  subscription_management_group_association_enabled = true
  subscription_management_group_id                  = var.management_group_name

  subscription_tags = each.value.tags

  resource_group_creation_enabled = true
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
  }

  # role assignments
  role_assignment_enabled = true
  role_assignments = {
    subscription_uaa_staff = {
      principal_id   = var.subscription_owner_object_id
      definition     = "User Access Administrator"
      relative_scope = ""
      principal_type   = "User"
      # Condition restricts role assignments to specific data access roles:
      # - Key Vault Secrets User (4633458b-17de-408a-b874-0445c86b69e6)
      # - Key Vault Administrator (00482a5a-887f-4fb3-b363-3b7fe8e74483)
      # - Storage Blob Data Reader (2a2b9908-6ea1-4ae2-8e65-a410df84e7d1)
      # - Storage Blob Data Contributor (ba92f5b4-2d11-453d-a403-e96b0029c9fe)
      # - Storage Queue Data Reader (19e7f393-937e-4f77-808e-94535e297925)
      # - Storage Queue Data Contributor (974c5e8b-45b9-4653-ba55-5f855dd0fb88)
      # - Storage Table Data Reader (76199698-9eea-4c19-bc75-cec21354c6b6)
      # - Storage Table Data Contributor (0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3)
      # - Storage File Data Reader (81a9662b-bebf-436f-a333-f67b29880f12)
      # - Storage File Data Contributor (69566ab7-960f-475b-8e7c-b3118f30c6bd)
      # - Cosmos DB Account Reader Role (fbdf93bf-df7d-467e-a4d2-9458aa1360c8)
      # - Cosmos DB Contributor (230815da-be43-4aae-9cb4-875f7bd000aa)
      # - SQL DB Contributor (9b7fa17d-e63e-47b0-bb0a-15c516ac86ec)
      # - SQL DB Reader (b24988ac-6180-42a0-ab88-20f7382dd24c)
      condition        = "((!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})) OR (@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {4633458b-17de-408a-b874-0445c86b69e6, 00482a5a-887f-4fb3-b363-3b7fe8e74483, 2a2b9908-6ea1-4ae2-8e65-a410df84e7d1, ba92f5b4-2d11-453d-a403-e96b0029c9fe, 19e7f393-937e-4f77-808e-94535e297925, 974c5e8b-45b9-4653-ba55-5f855dd0fb88, 76199698-9eea-4c19-bc75-cec21354c6b6, 0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3, 81a9662b-bebf-436f-a333-f67b29880f12, 69566ab7-960f-475b-8e7c-b3118f30c6bd, fbdf93bf-df7d-467e-a4d2-9458aa1360c8, 230815da-be43-4aae-9cb4-875f7bd000aa, 9b7fa17d-e63e-47b0-bb0a-15c516ac86ec, b24988ac-6180-42a0-ab88-20f7382dd24c}))"
      condition_version = "2.0"
    }
    subscription_developers = {
      principal_id   = var.subscription_developer_group_object_id
      definition     = "Contributor"
      relative_scope = ""
      principal_type   = "Group"
    }
  }

  # umi variables
  umi_enabled = true
  user_managed_identities = {
    plan = {
      name     = "umi-${each.value.component_name}-plan-01"
      location = var.location
      resource_group_name = each.value.identity_rg
      resource_group_creation_enabled = false
      tags     = each.value.tags
      role_assignments = {
        reader = {
          definition     = "Reader"
          relative_scope = ""
        }
      }
    },
    apply = {
      name     = "umi-${each.value.component_name}-apply-01"
      location = var.location
      resource_group_name = each.value.identity_rg
      resource_group_creation_enabled = false
      tags     = each.value.tags
      role_assignments = {
        apply = {
          definition     = "Contributor"
          relative_scope = ""
        }
      }
    },
    app = {
      name     = "umi-${each.value.component_name}-app-01"
      location = var.location
      resource_group_name = each.value.application_rg
      resource_group_creation_enabled = false
      tags     = each.value.tags
    }
  }

  # route table variables
  route_table_enabled = true
  route_tables = {
    HubNetwork = {
      name                          = "rt-${each.value.component_name}-01"
      location                      = var.location
      resource_group_name           = each.value.network_rg
      bgp_route_propagation_enabled = false
      routes = {
        FirewallDefaultRoute = {
          name                   = "${var.application_short_name}-to-firewall"
          address_prefix         = "0.0.0.0/0"
          next_hop_type          = "VirtualAppliance"
          next_hop_in_ip_address = var.hub_fw_ip
        }
      }
    }
  }

  # network security group variables
  network_security_group_enabled = true
  network_security_groups = {
    default = {
      name                            = "nsg-${each.value.component_name}-01"
      location                        = var.location
      resource_group_name             = each.value.network_rg
      security_rules = {
        allow_outbound = {
          name       = "allow-spoke-outbound"
          priority   = 100
          direction  = "Outbound"
          access     = "Allow"
          protocol   = "Tcp"
          source_port_range            = "*"
          destination_port_range       = "*"
          source_address_prefixes      = [module.ip_calc[each.value.environment].address_prefixes["default"]]
          destination_address_prefixes = [var.hub_network_address_prefix]
          description                 = "Allow spoke outbound traffic to FW"
        }
        allow_inbound = {
          name       = "allow-spoke-inbound"
          priority   = 100
          direction  = "Inbound"
          access     = "Allow"
          protocol   = "Tcp"
          source_port_range            = "*"
          destination_port_range       = "*"
          source_address_prefixes      = [var.hub_network_address_prefix]
          destination_address_prefixes = [module.ip_calc[each.value.environment].address_prefixes["default"]]
          description                 = "Allow spoke inbound traffic to FW"
        }
      }
    }
  }

  # virtual network variables
  virtual_network_enabled = true
  virtual_networks = {
    primary = {
      name                            = "vnet-${each.value.component_name}-01"
      address_space                   = [local.address_spaces_required[each.value.environment]]
      resource_group_name             = each.value.network_rg
      resource_group_creation_enabled = false
      hub_peering_enabled             = true
      hub_network_resource_id         = var.hub_network_id
      hub_peering_direction           = "both"
      subnets = {
        subnet1 = {
          name             = "snet-${each.value.component_name}-01"
          address_prefixes = [module.ip_calc[each.value.environment].address_prefixes["default"]]
          private_endpoint_network_policies             = "Disabled"
          private_link_service_network_policies_enabled = false
          route_table = {
            key_reference = "HubNetwork"
          }
          network_security_group = {
            key_reference = "default"
          }
          default_outbound_access_enabled = false
        }
        subnet2 = {
          name             = "snet-${each.value.component_name}-02"
          address_prefixes = [module.ip_calc[each.value.environment].address_prefixes["private_endpoint"]]
          private_endpoint_network_policies             = "Disabled"
          private_link_service_network_policies_enabled = false
          default_outbound_access_enabled = false
          delegations = []
        }
      }
      hub_peering_options_tohub = {
        allow_forwarded_traffic       = false
        allow_gateway_transit         = false
        allow_virtual_network_access  = true
        peer_complete_vnets           = true
        use_remote_gateways           = true
      }
      hub_peering_options_fromhub = {
        allow_forwarded_traffic       = true
        allow_gateway_transit         = true
        allow_virtual_network_access  = true
        peer_complete_vnets           = true
        use_remote_gateways           = false
      }
    }
  }
}

module "ado_svc_conn" {
  source  = "../../modules/azure_devops_svc_conn"
  for_each = local.federated_credentials

  service_endpoint_name = each.value.service_endpoint_name
  principal_id = each.value.umi_principal_id
  tenant_id = each.value.umi_tenant_id
  subscription_id = each.value.subscription_id
  subscription_name = each.value.subscription_name
  credential_name = each.value.credential_name
  resource_group_name = each.value.resource_group_name
  umi_resource_id = each.value.umi_resource_id

  azure_devops_organization_url = var.azure_devops_organization_url
  azure_devops_project_name    = var.azure_devops_project_name

  key_vault_name = var.key_vault_name
  key_vault_rg = var.key_vault_rg
  pat_secret_name = var.pat_secret_name
}
