terraform {
  required_version = "~> 1.10"
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.2"
    }
  }
  backend "azurerm"{
    use_azuread_auth = true
    use_msi = true
  }

}

provider "azapi" {
  use_msi = true
}

data "azurerm_client_config" "current" {
}
