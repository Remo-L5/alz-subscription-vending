variable "application_name" {
  description = "The name of the Application or Workload."
  type        = string
}

variable "application_short_name" {
  description = "The short name of the Application or Workload."
  type        = string
}

variable "environments" {
  description = "List of environments."
  type        = map(string)
  default = {
    "test" = "10.0.0.0/24"
    "prod" = "10.0.1.0/24"
  }
}

variable "location" {
  description = "The location name."
  type        = string
  default     = "westus2"
  validation {
    condition     = contains(["westus2", "westus3"], var.location)
    error_message = "The location name must be either 'westus2' or 'westus3'."
  }
}

variable "management_group_name" {
  description = "The name of the Management Group."
  type        = string
  default     = "alz-landingzones"
}

variable "subscription_resource_providers" {
  description = "The resource providers and their features for the subscription. Map of provider names to a set of features to enable."
  type        = map(set(string))
  default = {
    "Microsoft.Network"       = []
    "Microsoft.Compute"       = []
    "Microsoft.Storage"       = []
    "Microsoft.KeyVault"      = []
    "Microsoft.PolicyInsights" = []
  }
}