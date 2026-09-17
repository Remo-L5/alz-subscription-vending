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
  type = map(map(object({
    address_space = map(string)
  })))
  validation {
    condition = alltrue([
      for env, locs in var.environments : alltrue([
        for loc, cfg in locs : length(cfg.address_space) > 0
      ])
    ])
    error_message = "Each environment/location must define at least one address_space entry."
  }
  default = {
    "test" = {
      eastus = {
        address_space = {
          primary = "10.0.2.0/24"
        }
      }
      westus = {
        address_space = {
          primary = "10.0.3.0/24"
        }
      }
    }
    "prod" = {
      eastus = {
        address_space = {
          primary = "10.0.4.0/24"
        }
      }
      westus = {
        address_space = {
          primary = "10.0.5.0/24"
        }
      }
    }
  }
}


variable "primary_location" {
  description = "The location name."
  type        = string
  default     = "eastus"
  validation {
    condition     = contains(["eastus", "westus"], var.primary_location)
    error_message = "The location name must be either 'eastus' or 'westus'."
  }
}

variable "management_group_name" {
  description = "The name of the Management Group."
  type        = string
  default     = "alz-landingzones"
}

variable "resource_groups_additional" {
  type = map(object({
    suffix = string
  }))
  default = {}
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