data "azuredevops_project" "ado_alz" {
  name  = var.azure_devops_project_name
}

data "azurerm_key_vault" "core" {
  name                = var.key_vault_name
  resource_group_name = var.key_vault_rg
}

data "azurerm_key_vault_secret" "pat" {
  name      = var.pat_secret_name
  key_vault_id = data.azurerm_key_vault.core.id
}