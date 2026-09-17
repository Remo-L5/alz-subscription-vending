module "ado" {
  source = "../../../modules/azure_devops_svc_conn"

  for_each = local.federated_credentials
  
  azure_devops_organization_url = var.azure_devops_organization_url
  azure_devops_project_name = var.azure_devops_project_name
  key_vault_name = var.key_vault_name
  key_vault_rg = var.key_vault_rg
  pat_secret_name = var.pat_secret_name
  service_endpoint_name = each.value.service_endpoint_name
  principal_id = each.value.umi_principal_id
  tenant_id = each.value.umi_tenant_id
  subscription_id = each.value.subscription_id
  subscription_name = each.value.subscription_name
  credential_name = each.value.credential_name
  resource_group_name = each.value.resource_group_name
  umi_resource_id = each.value.umi_resource_id
}