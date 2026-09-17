targetScope = 'managementGroup'

param applicationName string
param applicationShortName string
param environments object
param location string = deployment().location

// Subscription Parameters
param subscriptionBillingScope string
param subscriptionWorkload string = 'Production'
param subscriptionTenantId string = ''
param subscriptionOwnerId string
param subscriptionManagementGroupAssociationEnabled bool = true
param subscriptionManagementGroupId string

param virtualNetworkEnabled bool = false
param virtualNetworkLocation string = deployment().location
param virtualNetworkPeeringEnabled bool = false
param hubNetworkResourceId string
param hubFirewallNextHopIpAddress string
param hubVirtualNetworkAddressSpace string = ''
param additionalVirtualNetworks array = []

param roleAssignmentEnabled bool = true
param roleAssignments array = []

param deploymentScriptResourceGroupName string = 'rg-${applicationShortName}-${deployment().location}'
param deploymentScriptName string = 'ds-subscription-setup-${applicationShortName}-${deployment().location}'
param deploymentScriptManagedIdentityName string = 'mi-subscription-vending'

param resourceProviders object

var resourceBaseName = '${toLower(applicationShortName)}-${toLower(location)}'

module lzVending 'br/public:avm/ptn/lz/sub-vending:0.4.0' =  [for env in items(environments): {
  name: 'lzVending-${toLower(env.key)}'
  params: {
    // Subscription Parameters
    subscriptionAliasEnabled: true
    subscriptionDisplayName: '${toUpper(applicationName)} ${toUpper(env.value)}'
    subscriptionAliasName: '${toLower(applicationShortName)}-${toLower(env.value)}'
    subscriptionBillingScope: subscriptionBillingScope
    subscriptionWorkload: subscriptionWorkload
    subscriptionTenantId: subscriptionTenantId
    subscriptionOwnerId: subscriptionOwnerId
    subscriptionManagementGroupAssociationEnabled: subscriptionManagementGroupAssociationEnabled
    subscriptionManagementGroupId: subscriptionManagementGroupId
    subscriptionTags: {
      Application: applicationName
      Environment: env.key
    }
    // Virtual Network Parameters
    virtualNetworkEnabled: virtualNetworkEnabled
    virtualNetworkResourceGroupName: 'rg-${resourceBaseName}-${toLower(env.key)}-networking-001'
    virtualNetworkResourceGroupTags: {
      Application: applicationName
      Environment: env.key
    }
    virtualNetworkResourceGroupLockEnabled: false
    virtualNetworkLocation: virtualNetworkLocation
    virtualNetworkName: 'vnet-${resourceBaseName}-${toLower(env.key)}-001'
    virtualNetworkTags: {
      Application: applicationName
      Environment: env.key
    }
    additionalVirtualNetworks: additionalVirtualNetworks // For future implementation
    virtualNetworkAddressSpace: [env.value.virtualNetworkAddressSpace]
    virtualNetworkDnsServers: []
    virtualNetworkSubnets: env.value.subnets
    virtualNetworkPeeringEnabled: virtualNetworkPeeringEnabled
    hubNetworkResourceId: hubNetworkResourceId
    virtualNetworkUseRemoteGateways: virtualNetworkEnabled && virtualNetworkPeeringEnabled

    //Route Table Parameters
    routeTablesResourceGroupName: 'rg-${resourceBaseName}-${toLower(env.key)}-networking-001'
    routeTables: virtualNetworkEnabled && virtualNetworkPeeringEnabled ? [] : [
      {
        name: 'rt-fw-next-hop-${resourceBaseName}-${toLower(env.key)}-001'
        location: virtualNetworkLocation
        tags: {
          Application: applicationName
          Environment: env.key
        }
        routes: [
          {
            name: 'route-to-hub-via-fw'
            properties: {
              addressPrefix: '0.0.0.0/0'
              nextHopType: 'VirtualAppliance'
              nextHopIpAddress: hubFirewallNextHopIpAddress
            }
          }
        ]
      }
    ]

    //Network Security Group Parameters
    networkSecurityGroupResourceGroupName: 'rg-${resourceBaseName}-${toLower(env.key)}-networking-001'
    networkSecurityGroups: virtualNetworkEnabled ? [] :[
      {
        name: 'nsg-${resourceBaseName}-${toLower(env.key)}-001'
        location: virtualNetworkLocation
        tags: {
          Application: applicationName
          Environment: env.key
        }
        securityRules: [
          {
            name: 'Allow-Inbound-Hub-Firewall'
            properties: {
              priority: 1100
              direction: 'Inbound'
              access: 'Allow'
              protocol: '*'
              sourceAddressPrefix: hubVirtualNetworkAddressSpace
              sourcePortRange: '*'
              destinationAddressPrefix: env.value.addressSpace
              destinationPortRange: '*'
            }
          }
          {
            name: 'Allow-Outbound-Hub-Firewall'
            properties: {
              priority: 1100
              direction: 'Outbound'
              access: 'Allow'
              protocol: '*'
              sourceAddressPrefix: env.value.addressSpace
              sourcePortRange: '*'
              destinationAddressPrefix: hubVirtualNetworkAddressSpace
              destinationPortRange: '*'
            }
          }
        ] 
      }
    ]

    // RBAC Parameters
    roleAssignmentEnabled: roleAssignmentEnabled
    roleAssignments: roleAssignments

    //User Assigned Managed Identity Parameters
    userAssignedIdentityResourceGroupName : 'rg-${resourceBaseName}-${toLower(env.key)}-001'
    userAssignedManagedIdentities : [
      {
        name: 'uami-${resourceBaseName}-${toLower(env.key)}-001'
        location: location
        tags: {
          Application: applicationName
          Environment: env.key
        }
        roleAssignments: []
      }
    ]
    userAssignedIdentitiesResourceGroupLockEnabled: false


    deploymentScriptResourceGroupName: deploymentScriptResourceGroupName
    deploymentScriptName: deploymentScriptName
    deploymentScriptManagedIdentityName: deploymentScriptManagedIdentityName

    resourceProviders: resourceProviders
  }
}]
