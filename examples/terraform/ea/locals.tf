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

  environment_short_names = {
    "test" : "test",
    "dev" : "dev",
    "prod" : "prd"
  }

  default_resource_groups_types = {
    vnetrg = {
      type = "network"
    }
    mainrg = {
      type = "application"
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
    for env, location in var.environments : env => {
      for location_key, location_value in location : "hub-${location_key}" => {
        name               = "nsg-${var.application_short_name}-${env}-${location_key}-01"
        location           = location_key
        resource_group_key = "${env}-${location_key}-vnetrg"
        security_rules = {
          allow_outbound = {
            name                         = "allow-${location_key}-spoke-outbound"
            priority                     = 100
            direction                    = "Outbound"
            access                       = "Allow"
            protocol                     = "Tcp"
            source_port_range            = "*"
            destination_port_range       = "*"
            source_address_prefixes      = [location_value.address_space]
            destination_address_prefixes = local.location_config[location_key].hub_network_address_prefixes
            description                  = "Allow spoke outbound traffic to hub"
          }
          allow_inbound = {
            name                         = "allow-${location_key}-spoke-inbound"
            priority                     = 100
            direction                    = "Inbound"
            access                       = "Allow"
            protocol                     = "Tcp"
            source_port_range            = "*"
            destination_port_range       = "*"
            source_address_prefixes      = local.location_config[location_key].hub_network_address_prefixes
            destination_address_prefixes = [location_value.address_space]
            description                  = "Allow spoke inbound traffic from hub"
          }
        }
      }
    }
  }

  default_virtual_networks = {
    for env, location in var.environments : env => {
      for location_key, location_value in location : location_key => {
        name                    = "vnet-${var.application_short_name}-${env}-${location_key}-01"
        location                = location_key
        address_space           = [location_value.address_space]
        dns_servers             = local.location_config[location_key].dns_servers
        ddos_protection_enabled = false
        ddos_protection_plan_id = null
        resource_group_key      = "${env}-${location_key}-vnetrg"
        hub_peering_enabled     = var.peer_spoke_to_hub
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

  virtual_network_config_by_location = merge([
    for env, locations in var.environments : {
      for location_key, location_value in locations : "${env}-${location_key}" => {
        virtual_network_address_space = location_value.address_space
        location                      = location_key
        subnet_cidr_blocks = {
          for subnet_name, subnet_config in var.virtual_network_subnets : subnet_name => subnet_config.cidr_block
        }
      }
    }
  ]...)

  subscriptions_to_provision = {
    for env, locations in var.environments : env => {
      component_name = "${var.application_short_name}-${env}"
      resource_groups_to_provision = {
        for k, v in merge(local.default_resource_groups, local.custom_resource_groups) : k => v
        if startswith(k, "${env}-")
      }
      environment = env
      locations   = var.var.primary_location
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
        for subnet_key, subnet_config in var.virtual_network_subnets : subnet_key => {
          name              = "snet-${var.application_short_name}-${env}-${local.location_config[location_key].location}-${subnet_key}"
          address_prefixes  = [module.ip_calc["${env}-${location_key}"].address_prefixes[subnet_key]]
          service_endpoints = lookup(subnet_config, "service_endpoints", [])
          delegations                                   = lookup(subnet_config, "delegations", [])
          private_endpoint_network_policies             = "Disabled"
          private_link_service_network_policies_enabled = false
          default_outbound_access_enabled               = false
          route_table = var.hub_peering_enabled ? {
            key_reference = "hub-${location_key}"
          } : null
          network_security_group = {
            key_reference = "hub-${location_key}"
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

}

