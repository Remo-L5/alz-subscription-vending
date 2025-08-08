module "ip_calc" {
  source  = "Azure/avm-utl-network-ip-addresses/azurerm"
  version = "0.1.0"

  address_space = var.spoke_vnet_address_space
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
      condition        = "((Microsoft.Authorization/roleAssignments/write/action == 'Microsoft.Authorization/roleAssignments/write') && (roleDefinitionId Matches '.*(Key Vault Secrets User|Key Vault Administrator|Storage Blob Data Reader|Storage Blob Data Contributor|Storage Queue Data Reader|Storage Queue Data Contributor|Storage Table Data Reader|Storage Table Data Contributor|Storage File Data Reader|Storage File Data Contributor|Cosmos DB Account Reader Role|Cosmos DB Contributor|SQL DB Contributor|SQL DB Reader).*'))"
      conditionVersion = "2.0"
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
          source_address_prefixes      = [var.spoke_vnet_address_space]
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
          destination_address_prefixes = [var.spoke_vnet_address_space]
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
      address_space                   = [var.spoke_vnet_address_space]
      resource_group_name             = each.value.network_rg
      resource_group_creation_enabled = false
      hub_peering_enabled             = true
      hub_network_resource_id         = var.hub_network_id
      hub_peering_direction           = "both"
      subnets = {
        subnet1 = {
          name             = "snet-${each.value.component_name}-01"
          address_prefixes = [module.ip_calc.address_prefixes["default"]]
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
          address_prefixes = [module.ip_calc.address_prefixes["private_endpoint"]]
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
