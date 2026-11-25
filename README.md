# alz-subscription-vending

## EA Terraform example

The [EA example](examples/terraform/ea) applies a shared tag map to subscriptions,
default and additional resource groups, route tables, network security groups,
virtual networks, managed identities, capacity reservation groups/reservations,
Key Vaults, and private endpoints. Child resources without tag support (such as
subnets, routes, peerings, and role assignments) are not tagged.

The existing `Application`, `ApplicationShortName`, and `Environment` tags are
joined by:

| Input | Tag |
| --- | --- |
| `department_name` | `DepartmentName` |
| `department_billing_id` | `DepartmentBillingId` |
| `service_agreement_name` | `ServiceAgreementName` |
| `service_number` | `ServiceNumber` |

These four inputs default to `Update Required`; supply the actual values before
deployment. Identities retain their additional `Role` tag. Azure Policy remains
responsible for inheritance/remediation on resources created outside vending.

The vending AVM owns the following assignments at each provisioned subscription:

| Identity | Roles |
| --- | --- |
| `app` | Reader |
| `plan` | Reader |
| `apply` | Custom Workload Contributor; conditional User Access Administrator |

**Prerequisite:** create `Custom Workload Contributor` in the associated
management-group hierarchy before vending subscriptions. This example looks it
up by name at subscription scope; it does not create or change the custom role.
Its permissions must be reviewed centrally, including exclusions for privileged
authorization operations, so it cannot bypass the conditional delegation.
`NotActions` are exclusions from a role, not deny assignments; other assignments
can still grant those permissions. The vending principal needs permission to
create the subscriptions/resources and these role assignments.

The delegation allowlist in `locals.tf` references built-in Key Vault, Storage,
Cosmos DB account-reader, and Service Bus roles by name through the pinned AVM
role-definition catalog. Both role-assignment writes (`@Request`) and deletes
(`@Resource`) are restricted to that list using condition version `2.0`.
Unlike the original write-only snippet, this also prevents deleting unrelated
role assignments. It does not restrict recipient principals within that list.
Cosmos DB SQL API native data roles are outside this Azure RBAC mechanism.
Existing vault-scoped identity assignments remain unchanged.

### Subnet-level NVA routing

Set `subnet_level_nva_routing_enabled = true` to add explicit subnet-prefix
routes alongside the existing `0.0.0.0/0` firewall route. Each environment's
route tables receive routes for all of that environment's subnets across its
locations and address spaces, never another environment's subnets. Each route
uses `VirtualAppliance` and the hub firewall/NVA IP for the route table's location.
More-specific subnet routes steer inter-subnet traffic through the NVA rather
than relying only on NSGs or the default route.

The flag defaults to `false` (no routing change) and requires both
`virtual_network_enabled` and `hub_peering_enabled`. Existing route-table
associations and NSGs are retained. Ensure the NVA supports forwarding, has
appropriate firewall rules and connectivity to all destination prefixes, and
has symmetric return paths. Private endpoint network policies are unchanged;
their more-specific endpoint routes may still bypass the NVA.

The MCA and Bicep examples are unchanged.