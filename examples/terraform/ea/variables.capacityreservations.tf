variable "vm_sku_reservations_by_environment" {
  description = "Map of environment names to lists of VM SKUs for creating on-demand capacity reservations."
  type        = map(list(string))
  default     = {}

  # Example:
  # {
  #   "prod" = ["Standard_D4s_v3", "Standard_E8s_v5"]
  #   "test" = ["Standard_D2s_v3"]
  # }
}

variable "capacity_reservation_enabled" {
  description = "Enable creation of on-demand capacity reservations."
  type        = bool
  default     = false
}
