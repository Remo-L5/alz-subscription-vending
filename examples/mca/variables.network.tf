variable "spoke_vnet_address_space" {
    description = "CIDR notation for the spoke vnet address space."
    type        = string
}

variable "hub_network_id" {
    description = "The ID of the hub network."
    type        = string
}

variable "hub_fw_ip" {
    description = "The private IP address of the hub firewall."
    type        = string
}

variable "hub_network_address_prefix" {
    description = "CIDR notation for the hub network address space."
    type        = string
}
