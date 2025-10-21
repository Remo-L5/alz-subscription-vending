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

variable "virtual_network_subnets" {
  description = "The subnet prefixes of the Virtual Network."
  type =map(object({
    name              = string
    cidr_block        = number
    service_endpoints = optional(list(string))
    delegations       = optional(list(string))
  }))
  default = {
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