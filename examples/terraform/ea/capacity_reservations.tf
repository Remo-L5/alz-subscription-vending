# On-Demand Capacity Reservations
# 
# These resources create capacity reservation groups and individual reservations
# using the azapi provider. The initial quantity is set to 0, which always succeeds.
# After VMs are manually linked to the reservation, the quantity can be updated
# manually to match the number of linked VMs.
#
# The ignore_body_changes lifecycle prevents Terraform from resetting the quantity
# back to 0 on subsequent applies, preserving any manual quantity updates.

# Capacity Reservation Groups - one per environment (using map to avoid set ordering issues)
resource "azapi_resource" "capacity_reservation_group" {
  for_each = var.capacity_reservation_enabled ? local.capacity_reservation_groups : {}

  type      = "Microsoft.Compute/capacityReservationGroups@2024-07-01"
  name      = each.value.group_name
  location  = each.value.location
  parent_id = module.lz_vending[each.value.environment].resource_group_resource_ids[each.value.resource_group_key]

  body = {
    properties = {
      sharingProfile = {
        subscriptionIds = []
      }
    }
    zones = []
  }

  tags = local.subscriptions_to_provision[each.value.environment].tags
}

# Individual Capacity Reservations - one per SKU per environment
# Initial capacity is 0 (always succeeds). After creation:
# 1. Create VMs of this SKU
# 2. Manually link VMs to the capacity reservation
# 3. Update the capacity to match the number of linked VMs (will always succeed)
# The ignore_body_changes ensures Terraform preserves the manual capacity updates
resource "azapi_resource" "capacity_reservation" {
  for_each = var.capacity_reservation_enabled ? local.capacity_reservations_flat : {}

  type      = "Microsoft.Compute/capacityReservationGroups/capacityReservations@2024-07-01"
  name      = each.value.reservation_name
  location  = each.value.location
  parent_id = azapi_resource.capacity_reservation_group[each.value.crg_key_name].id

  body = {
    sku = {
      name = each.value.sku
      # Initial capacity = 0 always succeeds
      # Subsequent manual updates are preserved by ignore_body_changes
      capacity = 0
    }
    properties = {}
    zones      = []
  }

  tags = local.subscriptions_to_provision[each.value.environment].tags

  # Prevent Terraform from resetting the capacity back to 0 on subsequent applies
  # This allows manual updates to the capacity to be preserved
  lifecycle {
    ignore_changes = [body.sku.capacity]
  }

}