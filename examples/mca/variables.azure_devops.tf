variable "key_vault_name" {
    type = string
}

variable "key_vault_rg" {
  type = string
}

variable "pat_secret_name" {
  type = string
}

variable "azure_devops_organization_url" {
    description = "The URL of the Azure DevOps organization."
    type        = string
}

variable "azure_devops_project_name" {
    description = "The project name within the Azure DevOps organization."
    type        = string
}