module "ip_calc" {
  source  = "Azure/avm-utl-network-ip-addresses/azurerm"
  version = "0.1.0"

  for_each         = local.subscriptions_to_provision
  address_space    = each.value.virtual_network_address_space
  address_prefixes = each.value.subnet_cidr_blocks
}

module "lz_vending" {
  source     = "Azure/lz-vending/azurerm"
  version    = "6.0.0" # change this to your desired version, https://www.terraform.io/language/expressions/version-constraints
  # Set the default location for resources
  for_each = local.subscriptions_to_provision

  location = var.location

  # subscription variables
  subscription_update_existing = false
  subscription_alias_enabled   = false
  subscription_billing_scope   = "/providers/Microsoft.Billing/billingAccounts/${var.billing_account_id}/billingProfiles/${var.billing_profile_id}"
  subscription_display_name    = "${upper(var.application_name)}-${upper(each.value.environment)}"
  subscription_alias_name      = "${lower(var.application_short_name)}-${lower(each.value.environment)}"
  subscription_workload        = "Production"

  # management group association variables
  subscription_management_group_association_enabled = true
  subscription_management_group_id                  = var.management_group_name

  subscription_register_resource_providers_enabled      = true
  subscription_register_resource_providers_and_features = var.subscription_resource_providers

  subscription_tags = each.value.tags

  resource_group_creation_enabled = true
  resource_groups = {
    vnetrg = {
      name     = "vnetrg"
      location = var.location
    }
    mainrg = {
      name     = "mainrg"
      location = var.location
    }
  }

  # role assignments TODO
  role_assignment_enabled = true
  role_assignments = {
    # subscription_uaa_staff = {
    #   principal_id   = var.subscription_owner_object_id
    #   definition     = "User Access Administrator"
    #   relative_scope = ""
    #   principal_type = "User"
    #   # Condition restricts role assignments to specific data access roles:
    #   # - Key Vault Secrets User (4633458b-17de-408a-b874-0445c86b69e6)
    #   # - Key Vault Administrator (00482a5a-887f-4fb3-b363-3b7fe8e74483)
    #   # - Storage Blob Data Reader (2a2b9908-6ea1-4ae2-8e65-a410df84e7d1)
    #   # - Storage Blob Data Contributor (ba92f5b4-2d11-453d-a403-e96b0029c9fe)
    #   # - Storage Queue Data Reader (19e7f393-937e-4f77-808e-94535e297925)
    #   # - Storage Queue Data Contributor (974c5e8b-45b9-4653-ba55-5f855dd0fb88)
    #   # - Storage Table Data Reader (76199698-9eea-4c19-bc75-cec21354c6b6)
    #   # - Storage Table Data Contributor (0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3)
    #   # - Storage File Data Reader (81a9662b-bebf-436f-a333-f67b29880f12)
    #   # - Storage File Data Contributor (69566ab7-960f-475b-8e7c-b3118f30c6bd)
    #   # - Cosmos DB Account Reader Role (fbdf93bf-df7d-467e-a4d2-9458aa1360c8)
    #   # - Cosmos DB Contributor (230815da-be43-4aae-9cb4-875f7bd000aa)
    #   # - SQL DB Contributor (9b7fa17d-e63e-47b0-bb0a-15c516ac86ec)
    #   # - SQL DB Reader (b24988ac-6180-42a0-ab88-20f7382dd24c)
    #   condition         = "((!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})) OR (@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {4633458b-17de-408a-b874-0445c86b69e6, 00482a5a-887f-4fb3-b363-3b7fe8e74483, 2a2b9908-6ea1-4ae2-8e65-a410df84e7d1, ba92f5b4-2d11-453d-a403-e96b0029c9fe, 19e7f393-937e-4f77-808e-94535e297925, 974c5e8b-45b9-4653-ba55-5f855dd0fb88, 76199698-9eea-4c19-bc75-cec21354c6b6, 0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3, 81a9662b-bebf-436f-a333-f67b29880f12, 69566ab7-960f-475b-8e7c-b3118f30c6bd, fbdf93bf-df7d-467e-a4d2-9458aa1360c8, 230815da-be43-4aae-9cb4-875f7bd000aa, 9b7fa17d-e63e-47b0-bb0a-15c516ac86ec, b24988ac-6180-42a0-ab88-20f7382dd24c}))"
    #   condition_version = "2.0"
    # }
    # subscription_developers = {
    #   principal_id   = var.subscription_developer_group_object_id
    #   definition     = "Custom Workload Contributor"
    #   relative_scope = ""
    #   principal_type = "Group"
    # }
  }

  # umi variables
  umi_enabled = true
  user_managed_identities = {
    app = {
      name                            = "umi-${each.value.component_name}-app-01"
      location                        = var.location
      resource_group_key              = "mainrg"
      tags                            = each.value.tags
    }
  }

  # route table variables
  route_table_enabled = var.virtual_network_enabled && var.hub_peering_enabled
  route_tables = {
    HubNetwork = {
      name                          = "rt-${each.value.component_name}-01"
      location                      = var.location
      resource_group_key           = "vnetrg"
      bgp_route_propagation_enabled = false
      routes = {
        FirewallDefaultRoute = {
          name                   = "${var.application_short_name}-to-firewall"
          address_prefix         = "0.0.0.0/0"
          next_hop_type          = "VirtualAppliance"
          next_hop_in_ip_address = local.location_config[var.location].hub_network_fw_ip
        }
      }
    }
  }

  # network security group variables
  network_security_group_enabled = var.virtual_network_enabled
  network_security_groups = {
    default = {
      name                = "nsg-${each.value.component_name}-01"
      location            = var.location
      resource_group_key  = "vnetrg"
      security_rules = {
        allow_outbound = {
          name                         = "allow-spoke-outbound"
          priority                     = 100
          direction                    = "Outbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_range            = "*"
          destination_port_range       = "*"
          source_address_prefixes      = [each.value.virtual_network_address_space]
          destination_address_prefixes = [local.location_config[var.location].hub_network_address_prefix]
          description                  = "Allow spoke outbound traffic to FW"
        }
        allow_inbound = {
          name                         = "allow-spoke-inbound"
          priority                     = 100
          direction                    = "Inbound"
          access                       = "Allow"
          protocol                     = "Tcp"
          source_port_range            = "*"
          destination_port_range       = "*"
          source_address_prefixes      = [local.location_config[var.location].hub_network_address_prefix]
          destination_address_prefixes = [each.value.virtual_network_address_space]
          description                  = "Allow spoke inbound traffic to FW"
        }
      }
    }
  }

  # virtual network variables
  virtual_network_enabled = var.virtual_network_enabled
  virtual_networks = {
    primary = {
      name                            = "vnet-${each.value.component_name}-01"
      address_space                   = [each.value.address_space]
      resource_group_key              = "vnetrg"
      hub_peering_enabled             = var.hub_peering_enabled
      hub_network_resource_id         = local.location_config[var.location].hub_network_resource_id
      hub_peering_direction           = "both"
      subnets                         = local.environment_subnets[each.key]
      hub_peering_options_tohub = {
        allow_forwarded_traffic      = false
        allow_gateway_transit        = false
        allow_virtual_network_access = true
        peer_complete_vnets          = true
        use_remote_gateways          = true
      }
      hub_peering_options_fromhub = {
        allow_forwarded_traffic      = true
        allow_gateway_transit        = true
        allow_virtual_network_access = true
        peer_complete_vnets          = true
        use_remote_gateways          = false
      }
    }
  }
}