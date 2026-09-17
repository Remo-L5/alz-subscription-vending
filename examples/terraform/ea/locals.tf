locals {
  location_config = {
    eastus : {
      hub_network_resource_id : "/subscriptions/${var.connectivity_subscription_id}/resourceGroups/rg-hub-eastus/providers/Microsoft.Network/virtualNetworks/vnet-hub-eastus",
      hub_network_address_prefix : "10.0.0.0/24",
      hub_network_fw_ip : "10.0.0.4"
      location : "eastus2"
      dns_servers : ["10.0.0.68"]
    }
    westus : {
      hub_network_resource_id : "/subscriptions/${var.connectivity_subscription_id}/resourceGroups/rg-hub-westus/providers/Microsoft.Network/virtualNetworks/vnet-hub-westus",
      hub_network_address_prefix : "10.0.0.0/24"
      hub_network_fw_ip : "10.0.1.4"
      location : "westus"
      dns_servers : ["10.0.1.68"]
    }
  }

  default_resource_groups_types = {
    vnetrg = {
      type = "network"
    }
    mainrg = {
      type = "application"
    }
    identityrg = {
      type = "identity"
    }
  }

  default_resource_groups = merge(flatten([
    for env, location in var.environments : [
      for location_key, location_value in location : {
        for resource_group_key, resource_group_value in local.default_resource_groups_types : "${env}-${location_key}-${resource_group_key}" => {
          name     = "rg-${var.application_short_name}-${env}-${location_key}-${resource_group_value.type}-01"
          location = location_key
        }
      }
    ]
  ])...)

  custom_resource_groups = merge(flatten([
    for env, location in var.environments : [
      for location_key, location_value in location : {
        for rg_key, rg_value in var.resource_groups_additional : "${env}-${location_key}-${rg_key}" => {
          name     = "rg-${var.application_short_name}-${env}-${location_key}-${rg_value.suffix}-01"
          location = location_key
        }
      }
    ]
  ])...)

  default_route_tables = {
    for env, location in var.environments : env => {
      for location_key, location_value in location : "hub-${location_key}" => {
        name                          = "rt-${var.application_short_name}-${env}-${location_key}-01"
        location                      = location_key
        resource_group_key            = "${env}-${location_key}-vnetrg"
        bgp_route_propagation_enabled = false
        routes = {
          FirewallDefaultRoute = {
            name                   = "${var.application_short_name}-to-firewall-${location_key}"
            address_prefix         = "0.0.0.0/0"
            next_hop_type          = "VirtualAppliance"
            next_hop_in_ip_address = local.location_config[location_key].hub_network_fw_ip
          }
        }
      }
    }
  }

  default_network_security_groups = {
    for env, location in var.environments : env => merge([
      for location_key, location_value in location : {
        for subnet_key, subnet_config in local.subnets_resolved[env][location_key] : "nsg-${location_key}-${subnet_key}" => {
          name               = "nsg-${var.application_short_name}-${env}-${location_key}-${subnet_key}"
          location           = location_key
          resource_group_key = "${env}-${location_key}-vnetrg"
          security_rules = {
            allow_outbound = {
              name                         = "allow-${location_key}-${subnet_key}-spoke-outbound"
              priority                     = 100
              direction                    = "Outbound"
              access                       = "Allow"
              protocol                     = "Tcp"
              source_port_range            = "*"
              destination_port_range       = "*"
              source_address_prefixes      = [module.ip_calc["${env}-${location_key}-${subnet_config.address_space_key}"].address_prefixes[subnet_key]]
              destination_address_prefixes = [local.location_config[location_key].hub_network_address_prefix]
              description                  = "Allow spoke outbound traffic to hub"
            }
            allow_inbound = {
              name                         = "allow-${location_key}-${subnet_key}-spoke-inbound"
              priority                     = 100
              direction                    = "Inbound"
              access                       = "Allow"
              protocol                     = "Tcp"
              source_port_range            = "*"
              destination_port_range       = "*"
              source_address_prefixes      = [local.location_config[location_key].hub_network_address_prefix]
              destination_address_prefixes = [module.ip_calc["${env}-${location_key}-${subnet_config.address_space_key}"].address_prefixes[subnet_key]]
              description                  = "Allow spoke inbound traffic from hub"
            }
          }
        } if try(subnet_config.enabled, true)
      }
    ]...)
  }

  default_virtual_networks = {
    for env, location in var.environments : env => {
      for location_key, location_value in location : location_key => {
        name                    = "vnet-${var.application_short_name}-${env}-${location_key}-01"
        location                = location_key
        address_space           = values(location_value.address_space)
        dns_servers             = local.location_config[location_key].dns_servers
        ddos_protection_enabled = false
        ddos_protection_plan_id = null
        resource_group_key      = "${env}-${location_key}-vnetrg"
        hub_peering_enabled     = var.hub_peering_enabled
        hub_network_resource_id = local.location_config[location_key].hub_network_resource_id
        hub_peering_direction   = "both"
        hub_peering_options_tohub = {
          allow_forwarded_traffic      = true
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
        subnets = local.environment_subnets[env][location_key]
      }
    }
  }

  # Flatten subnets so each subnet records the address_space_key it belongs to
  # (defaults to the first address_space key of its env/location).
  subnets_resolved = {
    for env, locations in var.environments : env => {
      for location_key, location_value in locations : location_key => {
        for subnet_key, subnet_config in lookup(var.virtual_network_subnets, env, {}) : subnet_key => merge(subnet_config, {
          address_space_key = coalesce(subnet_config.address_space_key, keys(location_value.address_space)[0])
        })
      }
    }
  }

  # One ip_calc instance per (env, location, address_space_key) so each VNet
  # address space gets its own carved-up prefix map.
  virtual_network_config_by_location = merge(flatten([
    for env, locations in var.environments : [
      for location_key, location_value in locations : [
        for as_key, as_cidr in location_value.address_space : {
          "${env}-${location_key}-${as_key}" = {
            virtual_network_address_space = as_cidr
            location                      = location_key
            subnet_cidr_blocks = {
              for subnet_key, subnet_config in local.subnets_resolved[env][location_key] :
              subnet_key => subnet_config.cidr_block
              if subnet_config.address_space_key == as_key
            }
          }
        }
      ]
    ]
  ])...)

  subscriptions_to_provision = {
    for env, locations in var.environments : env => {
      component_name = "${var.application_short_name}-${env}"
      resource_groups_to_provision = {
        for k, v in merge(local.default_resource_groups, local.custom_resource_groups) : k => v
        if startswith(k, "${env}-")
      }
      environment = env
      locations   = var.primary_location
      tags = {
        Application          = var.application_name
        ApplicationShortName = var.application_short_name
        Environment          = env
      }
    }
  }

  environment_subnets = {
    for env, location in var.environments : env => {
      for location_key, location_value in location : location_key => {
        for subnet_key, subnet_config in local.subnets_resolved[env][location_key] : subnet_key => {
          name                                          = "snet-${var.application_short_name}-${env}-${local.location_config[location_key].location}-${subnet_key}"
          address_prefixes                              = [module.ip_calc["${env}-${location_key}-${subnet_config.address_space_key}"].address_prefixes[subnet_key]]
          service_endpoints                             = lookup(subnet_config, "service_endpoints", [])
          delegations                                   = coalesce(lookup(subnet_config, "delegations", []), [])
          private_endpoint_network_policies             = "Disabled"
          private_link_service_network_policies_enabled = false
          default_outbound_access_enabled               = false
          route_table = var.hub_peering_enabled ? {
            key_reference = "hub-${location_key}"
          } : null
          network_security_group = {
            key_reference = "nsg-${location_key}-${subnet_key}"
          }
        }
      }
    }
  }

  umi_roles = {
    app   = {}
    plan  = {}
    apply = {}
  }

  default_user_managed_identities = {
    for env, locations in var.environments : env => merge(flatten([
      for location_key, location_value in locations : [
        {
          for role_key, role_value in local.umi_roles : "${env}-${location_key}-${role_key}" => {
            name               = "umi-${var.application_short_name}-${env}-${location_key}-${role_key}-01"
            location           = location_key
            resource_group_key = "${env}-${location_key}-mainrg"
            tags = {
              Application          = var.application_name
              ApplicationShortName = var.application_short_name
              Environment          = env
              Role                 = role_key
            }
          }
        }
      ]
    ])...)
  }

  # Hub route configurations for each address space (for hub_route_update resource)
  hub_route_configs = merge(flatten([
    for env, locations in var.environments : [
      for location_key, location_value in locations : [
        for address_space_key, address_space_cidr in location_value.address_space : {
          "${env}-${location_key}-${address_space_key}" = {
            environment       = env
            location          = location_key
            address_space_key = address_space_key
            address_prefix    = address_space_cidr
          }
        }
      ]
    ]
  ])...)

  # Flatten capacity reservations: create a map keyed by "env-location-sku" for each reservation
  capacity_reservations_flat = merge([
    for env, locations in var.environments : merge([
      for location_key, location_value in locations : {
        for sku in lookup(var.vm_sku_reservations_by_environment, env, []) : "${env}-${location_key}-${replace(lower(sku), "_", "-")}" => {
          environment        = env
          sku                = sku
          sku_safe_name      = replace(lower(sku), "_", "-")
          subscription_id    = module.lz_vending[env].subscription_id
          resource_group_key = "${env}-${location_key}-mainrg"
          crg_key_name       = "${env}-${location_key}"
          location           = location_key
          group_name         = "crg-${var.application_short_name}-${env}-${location_key}-01"
          reservation_name   = "cr-${var.application_short_name}-${env}-${location_key}-${replace(lower(sku), "_", "-")}"
        }
      }
    ]...)
  ]...)

  # Map of environments and locations that have capacity reservations
  capacity_reservation_groups = merge([
    for env, locations in var.environments : {
      for location_key, location_value in locations : "${env}-${location_key}" => {
        environment        = env
        location_key       = location_key
        skus               = lookup(var.vm_sku_reservations_by_environment, env, [])
        group_name         = "crg-${var.application_short_name}-${env}-${location_key}-01"
        location           = location_key
        resource_group_key = "${env}-${location_key}-mainrg"
      }
      if length(lookup(var.vm_sku_reservations_by_environment, env, [])) > 0
    }
  ]...)

  # Key Vaults - one per environment/location. The private endpoint is always
  # deployed into the 'private_endpoint' subnet.
  key_vaults = merge([
    for env, locations in var.environments : {
      for location_key, location_value in locations : "${env}-${location_key}" => {
        environment           = env
        location              = location_key
        vnet_key              = location_key
        resource_group_key    = "${env}-${location_key}-mainrg"
        name                  = substr(replace("kv${var.application_short_name}${env}${location_key}01", "/[^a-zA-Z0-9]/", ""), 0, 24)
        private_endpoint_name = "pep-kv-${var.application_short_name}-${env}-${location_key}-01"
        subnet_name           = local.environment_subnets[env][location_key][var.private_endpoint_subnet_key].name
      }
    }
  ]...)

  # Key Vault built-in role definition UUIDs, resolved via the AVM
  # avm-utl-roledefinitions utility module (module.role_definitions).
  key_vault_role_definitions = {
    crypto_user         = module.role_definitions.role_definition_rolename_to_name["Key Vault Crypto User"]
    secrets_user        = module.role_definitions.role_definition_rolename_to_name["Key Vault Secrets User"]
    certificate_user    = module.role_definitions.role_definition_rolename_to_name["Key Vault Certificate User"]
    crypto_officer      = module.role_definitions.role_definition_rolename_to_name["Key Vault Crypto Officer"]
    secrets_officer     = module.role_definitions.role_definition_rolename_to_name["Key Vault Secrets Officer"]
    certificate_officer = module.role_definitions.role_definition_rolename_to_name["Key Vault Certificates Officer"]
  }

  # Key Vault role assignments per user-assigned managed identity:
  #   plan  -> User roles    (crypto, secret, certificate)
  #   apply -> Officer roles (crypto, secret, certificate)
  #   app   -> User roles    (crypto, secret, certificate)
  key_vault_umi_roles = {
    plan  = ["crypto_user", "secrets_user", "certificate_user"]
    apply = ["crypto_officer", "secrets_officer", "certificate_officer"]
    app   = ["crypto_user", "secrets_user", "certificate_user"]
  }

  # Flatten to one entry per (env, location, umi_role, kv_role). The UAMI keys
  # match the lz_vending umi_principal_ids map keys ("${env}-${location}-${role}").
  key_vault_role_assignments = merge([
    for kv_key, kv in local.key_vaults : {
      for pair in flatten([
        for umi_role, kv_roles in local.key_vault_umi_roles : [
          for kv_role in kv_roles : {
            umi_role = umi_role
            kv_role  = kv_role
          }
        ]
        ]) : "${kv_key}-${pair.umi_role}-${pair.kv_role}" => {
        kv_key             = kv_key
        environment        = kv.environment
        umi_key            = "${kv_key}-${pair.umi_role}"
        role_definition_id = local.key_vault_role_definitions[pair.kv_role]
      }
    }
  ]...)

}

