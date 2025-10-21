terraform {
  required_version = "~> 1.10"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.2"
    }
  }
  backend "azurerm" {
    use_azuread_auth = true
    use_msi          = true
    # resource_group_name  = ""
    # storage_account_name = ""
    # container_name       = "lz-vending-tfstate"
    # key                  = "terraform.tfstate"

  }

}
provider "azurerm" {
  features {}
}

provider "azapi" {
  # Configuration options
}
