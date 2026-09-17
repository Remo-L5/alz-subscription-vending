using 'lz-vending.bicep'

param applicationName = 'ALZ Application'
param applicationShortName = 'alzapp'
param environments = {
  dev: {
    virtualNetworkAddressSpace: '10.0.0.0/24'
    subnets: [
      {
        name: 'default'
        addressPrefix: '10.0.0.0/26'
        networkSecurityGroup: ''
        serviceEndpoints: []
        defaultOutboundAccess: false
        routeTableName: ''
      }
    ]
  }
  test: {
    virtualNetworkAddressSpace: '10.0.1.0/24'
  }
}
// Subscription Parameters
param subscriptionBillingScope = ''
param subscriptionOwnerId = ''
param subscriptionManagementGroupId = ''


// Virtual Network Configuration
param virtualNetworkEnabled = true
param virtualNetworkPeeringEnabled = true
param hubNetworkResourceId = ''
param hubFirewallNextHopIpAddress = ''

// Role Assignment Configuration
param roleAssignmentEnabled = true
param roleAssignments = []

param resourceProviders = {
  'Microsoft.ApiManagement'             : []
    'Microsoft.AppPlatform'             : []
    'Microsoft.Authorization'           : []
    'Microsoft.Automation'              : []
    'Microsoft.AVS'                     : []
    'Microsoft.Blueprint'               : []
    'Microsoft.BotService'              : []
    'Microsoft.Cache'                   : []
    'Microsoft.Cdn'                     : []
    'Microsoft.CognitiveServices'       : []
    'Microsoft.Compute'                 : []
    'Microsoft.ContainerInstance'       : []
    'Microsoft.ContainerRegistry'       : []
    'Microsoft.ContainerService'        : []
    'Microsoft.CostManagement'          : []
    'Microsoft.CustomProviders'         : []
    'Microsoft.Databricks'              : []
    'Microsoft.DataLakeAnalytics'       : []
    'Microsoft.DataLakeStore'           : []
    'Microsoft.DataMigration'           : []
    'Microsoft.DataProtection'          : []
    'Microsoft.DBforMariaDB'            : []
    'Microsoft.DBforMySQL'              : []
    'Microsoft.DBforPostgreSQL'         : []
    'Microsoft.DesktopVirtualization'   : []
    'Microsoft.Devices'                 : []
    'Microsoft.DevTestLab'              : []
    'Microsoft.DocumentDB'              : []
    'Microsoft.EventGrid'               : []
    'Microsoft.EventHub'                : []
    'Microsoft.HDInsight'               : []
    'Microsoft.HealthcareApis'          : []
    'Microsoft.GuestConfiguration'      : []
    'Microsoft.KeyVault'                : []
    'Microsoft.Kusto'                   : []
    'microsoft.insights'                : []
    'Microsoft.Logic'                   : []
    'Microsoft.MachineLearningServices' : []
    'Microsoft.Maintenance'             : []
    'Microsoft.ManagedIdentity'         : []
    'Microsoft.ManagedServices'         : []
    'Microsoft.Management'              : []
    'Microsoft.Maps'                    : []
    'Microsoft.MarketplaceOrdering'     : []
    'Microsoft.Media'                   : []
    'Microsoft.MixedReality'            : []
    'Microsoft.Network'                 : []
    'Microsoft.NotificationHubs'        : []
    'Microsoft.OperationalInsights'     : []
    'Microsoft.OperationsManagement'    : []
    'Microsoft.PolicyInsights'          : []
    'Microsoft.PowerBIDedicated'        : []
    'Microsoft.Relay'                   : []
    'Microsoft.RecoveryServices'        : []
    'Microsoft.Resources'               : []
    'Microsoft.Search'                  : []
    'Microsoft.Security'                : []
    'Microsoft.SecurityInsights'        : []
    'Microsoft.ServiceBus'              : []
    'Microsoft.ServiceFabric'           : []
    'Microsoft.Sql'                     : []
    'Microsoft.Storage'                 : []
    'Microsoft.StreamAnalytics'         : []
    'Microsoft.TimeSeriesInsights'      : []
    'Microsoft.Web'                     : []
}
