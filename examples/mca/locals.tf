locals {
  invoice_section_name = "${var.org_code}-${lower(replace(var.application_name, " ", "-"))}"
  invoice_section_display_name = "${var.org_code} - ${var.application_name}"
  invoice_section_uri = "/providers/Microsoft.Billing/billingAccounts/${var.billing_account_id}/billingProfiles/${var.billing_profile_id}/invoiceSections/${local.invoice_section_name}"
   environments = [
    "test",
    "prod"
  ]
  address_spaces_required = {
    "test" = var.spoke_vnet_address_space_test
    "prod" = var.spoke_vnet_address_space_prod
  }
  subscription_resource_providers = { for provider in split(",", var.subscription_resource_providers) : provider => [] }
  
  subscriptions_to_provision = {
    for env in local.environments : "${var.application_short_name}_${env}" => {
      component_name = "${var.application_short_name}-${env}-${var.location}"
      network_rg     = "rg-${var.application_short_name}-${env}-${var.location}-network-01"
      identity_rg    = "rg-${var.application_short_name}-${env}-${var.location}-identity-01"
      application_rg = "rg-${var.application_short_name}-${env}-${var.location}-app-01"
      environment    = env
      tags = {
        Application      = var.application_name
        ApplicationShortName = var.application_short_name
        Environment      = env
      }
    }
  }

  federated_credentials = flatten([
    for sub_k, sub_v in module.lz_vending : [
      {
        for umi_k, umi_v in sub_v.umi_resource_ids : umi_k => {
          subscription_id     = sub_v.subscription_id
          subscription_name  = replace(sub_k, "_", " ")
          umi_resource_id   = umi_v
          umi_principal_id = sub_v.umi_principal_ids[umi_k]
          umi_tenant_id  = sub_v.umi_tenant_ids[umi_k]
          umi_client_id = sub_v.umi_client_ids[umi_k]
          resource_group_name = sub_v.resource_group_resource_ids["identityrg"]
          service_endpoint_name = "sc-${var.application_short_name}-${split(sub_k, "_")[1]}"
          credential_name = "${umi_k}-${split(sub_k, "_")[1]}-azuredevops"
        }
      }
    ]
  ])
}