

variable "principal_id" {
  type = string
  description = "The Principal ID of the User Assigned Managed Identity."
}

variable "tenant_id" {
  type = string
  description = "The Tenant ID of the User Assigned Managed Identity."
}

variable "subscription_id" {
  type = string
  description = "The Subscription ID of the User Assigned Managed Identity."
}

variable "subscription_name" {
  type = string
  description = "The Subscription Name of the User Assigned Managed Identity."
}

variable "credential_name" {
  type = string
  description = "The name of the Federated Identity Credential."
}

variable "resource_group_name" {
  type = string
  description = "The name of the Resource Group where the Federated Identity Credential is located."
}

variable "umi_resource_id" {
  type = string
  description = "The Resource ID of the User Managed Identity."
}
