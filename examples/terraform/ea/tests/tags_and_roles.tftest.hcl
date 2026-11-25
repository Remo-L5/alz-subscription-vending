mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id          = "00000000-0000-0000-0000-000000000001"
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000001"
      tenant_id                = "00000000-0000-0000-0000-000000000002"
    }
  }
}

mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id = "00000000-0000-0000-0000-000000000002"
    }
  }
}
mock_provider "random" {}

override_module {
  target = module.lz_vending
  outputs = {
    subscription_id          = "00000000-0000-0000-0000-000000000001"
    subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000001"
    resource_group_resource_ids = {
      test-eastus-mainrg = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test"
      test-westus-mainrg = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test-westus"
      prod-eastus-mainrg = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-prod"
    }
    virtual_network_resource_ids = {
      eastus = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-test"
      westus = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-test-westus"
    }
    umi_principal_ids = {
      test-eastus-app   = "00000000-0000-0000-0000-000000000003"
      test-eastus-plan  = "00000000-0000-0000-0000-000000000004"
      test-eastus-apply = "00000000-0000-0000-0000-000000000005"
      test-westus-app   = "00000000-0000-0000-0000-000000000009"
      test-westus-plan  = "00000000-0000-0000-0000-000000000010"
      test-westus-apply = "00000000-0000-0000-0000-000000000011"
      prod-eastus-app   = "00000000-0000-0000-0000-000000000006"
      prod-eastus-plan  = "00000000-0000-0000-0000-000000000007"
      prod-eastus-apply = "00000000-0000-0000-0000-000000000008"
    }
  }
}

variables {
  application_name             = "Example workload"
  application_short_name       = "example"
  billing_account_id           = "example-account"
  billing_profile_id           = "example-profile"
  connectivity_subscription_id = "00000000-0000-0000-0000-000000000001"
  department_name              = "Example department"
  department_billing_id        = "DEPT-001"
  service_agreement_name       = "Example agreement"
  service_number               = "REQ-001"
  private_endpoint_subnet_key  = "private_endpoint"
  hub_peering_enabled          = false
  capacity_reservation_enabled = true
  vm_sku_reservations_by_environment = {
    test = ["Standard_D2s_v3"]
    prod = ["Standard_D2s_v3"]
  }
  environments = {
    test = { eastus = { address_space = { primary = "10.0.2.0/24" } } }
    prod = { eastus = { address_space = { primary = "10.0.3.0/24" } } }
  }
  resource_groups_additional = {
    extra = { suffix = "extra" }
  }
}

run "propagate_tags_and_identity_roles" {
  command = plan

  assert {
    condition = alltrue(flatten([
      for tables in values(local.default_route_tables) : [
        for table in values(tables) : keys(table.routes) == ["FirewallDefaultRoute"]
      ]
    ]))
    error_message = "Subnet-level NVA routing must remain opt-in, preserving the original default route only."
  }

  assert {
    condition = alltrue([
      for env, subscription in local.subscriptions_to_provision : subscription.tags == {
        Application          = var.application_name
        ApplicationShortName = var.application_short_name
        Environment          = env
        DepartmentName       = var.department_name
        DepartmentBillingId  = var.department_billing_id
        ServiceAgreementName = var.service_agreement_name
        ServiceNumber        = var.service_number
      }
    ])
    error_message = "Each subscription must receive the supplied application, environment, department, and service tags."
  }

  assert {
    condition = alltrue(flatten([
      for env, subscription in local.subscriptions_to_provision : [
        for resource in concat(
          values(subscription.resource_groups_to_provision),
          values(local.default_route_tables[env]),
          values(local.default_network_security_groups[env]),
          values(local.default_virtual_networks[env])
        ) : resource.tags == subscription.tags
      ]
    ]))
    error_message = "Default/additional groups and network resources must inherit their own environment's tags."
  }

  assert {
    condition = alltrue(flatten([
      for env, identities in local.default_user_managed_identities : [
        for key, identity in identities : (
          identity.tags == merge(local.subscription_tags[env], { Role = split("-", key)[2] }) &&
          identity.role_assignments == local.umi_roles[identity.tags.Role].role_assignments
        )
      ]
    ]))
    error_message = "Every generated identity must retain Role, inherit shared tags, and pass its assignments into vending."
  }

  assert {
    condition = alltrue(flatten([
      for env, subscription in local.subscriptions_to_provision : [
        azapi_resource.key_vault["${env}-eastus"].tags == tomap(subscription.tags),
        azapi_resource.key_vault_private_endpoint["${env}-eastus"].tags == tomap(subscription.tags),
        azapi_resource.capacity_reservation_group["${env}-eastus"].tags == tomap(subscription.tags),
        azapi_resource.capacity_reservation["${env}-eastus-standard-d2s-v3"].tags == tomap(subscription.tags),
      ]
    ]))
    error_message = "Vaults, private endpoints, and capacity resources must retain the shared environment tags."
  }

  assert {
    condition = (
      local.umi_roles.app.role_assignments.subscription_reader.definition == "Reader" &&
      local.umi_roles.plan.role_assignments.subscription_reader.definition == "Reader" &&
      local.umi_roles.apply.role_assignments.subscription_contributor.definition == "Custom Workload Contributor" &&
      alltrue(flatten([
        for role in values(local.umi_roles) : [
          for assignment in values(role.role_assignments) :
          assignment.relative_scope == "" &&
          assignment.principal_type == "ServicePrincipal" &&
          assignment.definition_lookup_enabled
        ]
      ]))
    )
    error_message = "Identity assignments must use subscription scope, service principals, and role-name lookup."
  }

  assert {
    condition = (
      local.umi_roles.apply.role_assignments.subscription_uaa_conditional.definition == "User Access Administrator" &&
      local.umi_roles.apply.role_assignments.subscription_uaa_conditional.condition_version == "2.0" &&
      local.umi_roles.apply.role_assignments.subscription_uaa_conditional.condition == join(" AND ", [
        "((!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})) OR (@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${join(", ", values(local.uaa_delegable_role_ids))}}))",
        "((!(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})) OR (@Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${join(", ", values(local.uaa_delegable_role_ids))}}))",
      ]) &&
      alltrue([
        for name in ["Owner", "Contributor", "User Access Administrator", "Role Based Access Control Administrator"] :
        !contains(values(local.uaa_delegable_role_ids), module.role_definitions.role_definition_rolename_to_name[name])
      ])
    )
    error_message = "Delegation must constrain writes and deletes to the same resolved allowlist, excluding subscription administration roles."
  }
}

run "route_environment_subnets_through_nva" {
  command = plan

  variables {
    subnet_level_nva_routing_enabled = true
    hub_peering_enabled              = true
    environments = {
      test = {
        eastus = { address_space = { primary = "10.1.0.0/24", secondary = "10.1.1.0/24" } }
        westus = { address_space = { primary = "10.2.0.0/24", secondary = "10.2.1.0/24" } }
      }
      prod = {
        eastus = { address_space = { primary = "10.3.0.0/24", secondary = "10.3.1.0/24" } }
      }
    }
    virtual_network_subnets = {
      test = {
        default          = { name = "default", cidr_block = 26, address_space_key = "primary" }
        private_endpoint = { name = "private-endpoint", cidr_block = 26, address_space_key = "primary" }
        worker           = { name = "worker", cidr_block = 26, address_space_key = "secondary" }
      }
      prod = {
        default          = { name = "default", cidr_block = 26, address_space_key = "primary" }
        private_endpoint = { name = "private-endpoint", cidr_block = 26, address_space_key = "primary" }
        worker           = { name = "worker", cidr_block = 26, address_space_key = "secondary" }
      }
    }
  }

  assert {
    condition = alltrue(flatten([
      for env, tables in local.default_route_tables : [
        for table in values(tables) : (
          length(table.routes) == (env == "test" ? 7 : 4) &&
          toset([
            for key, route in table.routes : route.address_prefix if key != "FirewallDefaultRoute"
            ]) == toset(env == "test" ? [
            "10.1.0.0/26", "10.1.0.64/26", "10.1.1.0/26",
            "10.2.0.0/26", "10.2.0.64/26", "10.2.1.0/26"
          ] : ["10.3.0.0/26", "10.3.0.64/26", "10.3.1.0/26"])
        )
      ]
    ]))
    error_message = "Every route table must include exactly its environment's subnet prefixes across all locations and address spaces."
  }

  assert {
    condition = alltrue(flatten([
      for tables in values(local.default_route_tables) : [
        for table in values(tables) : (
          table.routes.FirewallDefaultRoute.address_prefix == "0.0.0.0/0" &&
          alltrue([
            for route in values(table.routes) :
            route.next_hop_type == "VirtualAppliance" &&
            route.next_hop_in_ip_address == (table.location == "eastus" ? "10.0.0.4" : "10.0.1.4")
          ]) &&
          length(distinct([for route in values(table.routes) : route.name])) == length(table.routes)
        )
      ]
    ]))
    error_message = "Routes must keep the default route, have unique names, and use the NVA local to the route table."
  }

  assert {
    condition = alltrue(flatten([
      for locations in values(local.environment_subnets) : [
        for location, subnets in locations : [
          for subnet in values(subnets) : subnet.route_table.key_reference == "hub-${location}"
        ]
      ]
    ]))
    error_message = "Subnets must retain their regional route-table associations."
  }
}

run "reject_nva_routing_without_hub_peering" {
  command = plan

  variables {
    subnet_level_nva_routing_enabled = true
    hub_peering_enabled              = false
  }

  expect_failures = [var.subnet_level_nva_routing_enabled]
}

run "reject_nva_routing_without_virtual_networks" {
  command = plan

  variables {
    subnet_level_nva_routing_enabled = true
    hub_peering_enabled              = true
    virtual_network_enabled          = false
  }

  expect_failures = [var.subnet_level_nva_routing_enabled]
}
