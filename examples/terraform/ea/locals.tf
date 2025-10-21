locals {
  location_config = {
    eastus : {
      hub_network_resource_id : "/subscriptions/${var.connectivity_subscription_id}/resourceGroups/rg-hub-${var.location}/providers/Microsoft.Network/virtualNetworks/vnet-hub-${var.location}",
      hub_network_address_prefix : "10.0.0.0/24",
      hub_network_fw_ip : "10.0.0.4"
    }
  }
  environment_short_names = {
    "test" : "test",
    "dev" : "dev",
    "prod" : "prd"
  }

  subscriptions_to_provision = {
    for env, address_space in var.environments : env => {
      component_name                = "${var.application_short_name}-${local.environment_short_names[env]}-${var.location}"
      network_rg                    = "rg-${var.application_short_name}-${local.environment_short_names[env]}-${var.location}-network-01"
      identity_rg                   = "rg-${var.application_short_name}-${local.environment_short_names[env]}-${var.location}-app-01"
      application_rg                = "rg-${var.application_short_name}-${local.environment_short_names[env]}-${var.location}-app-01"
      environment                   = env
      virtual_network_address_space = address_space
      subnet_cidr_blocks = {
        for subnet_name, subnet_config in var.virtual_network_subnets : subnet_name => subnet_config.cidr_block
      }
      tags = {
        Application          = var.application_name
        ApplicationShortName = var.application_short_name
        Environment          = env
      }
    }
  }

  environment_subnets = {
    for env in var.environments : env => {
      for subnet_key, subnet_config in var.virtual_network_subnets : subnet_key => {
        name                                          = "snet-${var.application_short_name}-${local.environment_short_names[env]}-${var.location}-${subnet_key}"
        address_prefixes                              = [module.ip_calc[env].address_prefixes[subnet_key]]
        service_endpoints                             = lookup(subnet_config, "service_endpoints", [])
        delegations                                   = lookup(subnet_config, "delegations", [])
        private_endpoint_network_policies             = "Disabled"
        private_link_service_network_policies_enabled = false
        default_outbound_access_enabled               = false
        route_table = var.hub_peering_enabled ? {
          key_reference = "HubNetwork"
        } : null
        network_security_group = {
          key_reference = "default"
        }
      }
    }
  }

}
