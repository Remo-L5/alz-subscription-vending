resource "azuredevops_serviceendpoint_azurerm" "service_endpoint" {
  project_id                             = data.azuredevops_project.ado_alz.id
  service_endpoint_name                  = var.service_endpoint_name
  description                            = "Managed by Terraform"
  service_endpoint_authentication_scheme = "WorkloadIdentityFederation"
  credentials {
    serviceprincipalid = var.principal_id
  }
  azurerm_spn_tenantid      = var.tenant_id
  azurerm_subscription_id   = var.subscription_id
  azurerm_subscription_name = var.subscription_name
}

resource "azurerm_federated_identity_credential" "federated_credential" {
  name                = var.credential_name
  resource_group_name = var.resource_group_name
  parent_id           = var.umi_resource_id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azuredevops_serviceendpoint_azurerm.service_endpoint.workload_identity_federation_issuer
  subject             = azuredevops_serviceendpoint_azurerm.service_endpoint.workload_identity_federation_subject
}