variable "connectivity_subscription_id" {
  description = "The ID of the connectivity subscription."
  type        = string
}

variable "virtual_network_enabled" {
  description = "Enable or disable the creation of a Virtual Network."
  type        = bool
  default     = true
}

variable "hub_peering_enabled" {
  description = "Determine if Hub peering is enabled. True or False"
  type        = bool
  default     = true
}

variable "subnet_level_nva_routing_enabled" {
  description = "Add a route for every subnet in an environment to each of that environment's route tables, using the route table location's hub NVA as the next hop. Requires virtual networks and hub peering."
  type        = bool
  default     = false
  nullable    = false

  validation {
    condition     = !var.subnet_level_nva_routing_enabled || (var.virtual_network_enabled && var.hub_peering_enabled)
    error_message = "Subnet-level NVA routing requires virtual_network_enabled and hub_peering_enabled to both be true."
  }
}

variable "private_endpoint_subnet_key" {
  description = "The key of the subnet to use for private endpoints. This key must exist in the `virtual_network_subnets` variable."
  type        = string
  default     = "app"
}

variable "virtual_network_subnets" {
  description = "The subnet prefixes of the Virtual Network. Each subnet may optionally specify `address_space_key` to indicate which entry of the location's `address_space` map it is carved from (defaults to the first address_space key)."
  type = map(map(object({
    name              = string
    cidr_block        = number
    address_space_key = optional(string)
    service_endpoints = optional(list(string))
    delegations = optional(list(
      object(
        {
          name = string
          service_delegation = object({
            name = string
          })
        }
      )
    ))
  })))
  default = {
    test = {
      default = {
        name              = "default"
        cidr_block        = 26
        service_endpoints = []
        delegations       = []
      }
      private_endpoint = {
        name              = "private-endpoint"
        cidr_block        = 26
        service_endpoints = []
        delegations       = []
      }
    }
    prod = {
      default = {
        name              = "default"
        cidr_block        = 26
        service_endpoints = []
        delegations       = []
      }
      private_endpoint = {
        name              = "private-endpoint"
        cidr_block        = 26
        service_endpoints = []
        delegations       = []
      }
    }
  }

}