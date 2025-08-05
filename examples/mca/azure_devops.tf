module "ado" {
  source = "./modules/federated_credentials"

  for_each = local.federated_credentials
  
  service_endpoint_name = each.value.service_endpoint_name
  principal_id = each.value.umi_principal_id
  tenant_id = each.value.umi_tenant_id
  subscription_id = each.value.subscription_id
  subscription_name = each.value.subscription_name
  credential_name = each.value.credential_name
  resource_group_name = each.value.resource_group_name
  umi_resource_id = each.value.umi_resource_id
}