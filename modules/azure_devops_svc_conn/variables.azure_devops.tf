variable "azure_devops_organization_url" {
    type = string  
    description = "The URL of the Azure DevOps organization."
}

variable "azure_devops_project_name" {
    type        = string
    description = "The project name within the Azure DevOps organization."
}

variable "service_endpoint_name" {
  type = string
  description = "The name of the Azure DevOps Service Endpoint."
}

variable "key_vault_name" {
    type = string
}

variable "key_vault_rg" {
  type = string
}

variable "pat_secret_name" {
  type = string
}