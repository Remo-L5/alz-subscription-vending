terraform {
  required_version = "~> 1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = "~> 1.9"
      }
  }
  backend "azurerm" {}

}

provider "azurerm" {
  subscription_id                 = var.subscription_id
  features {}
}

provider "azuredevops" {
  org_service_url = var.azure_devops_organization_url
  personal_access_token = data.azurerm_key_vault_secret.pat.value
}
