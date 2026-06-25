locals {
  # ===========================================================================
  # Effective Fabric identifiers — resolved from either the created workspace
  # (when create_fabric_resources = true) or the user-supplied inputs.
  # Downstream resources reference these locals instead of branching on the
  # flag themselves.
  # ===========================================================================

  effective_workspace_id = var.create_fabric_resources ? fabric_workspace.this[0].id : var.fabric_workspace_id

  # When the module creates the warehouse, derive the public SQL endpoint
  # from its `properties.connection_string` attribute. Assumption: the provider
  # returns a bare hostname like "xxx-yyy.datawarehouse.fabric.microsoft.com".
  # If a future provider version returns a full ADO.NET-style string, the
  # downstream trimsuffix() will still produce the right host_root.
  effective_sql_endpoint = var.create_fabric_resources ? fabric_warehouse.this[0].properties.connection_string : var.fabric_sql_endpoint

  # Workspace Identity object IDs — inline from fabric_workspace.identity when
  # bootstrapping, or read from the data.external az rest call in
  # fabric-workspace.tf when attaching to an existing workspace.
  effective_workspace_identity_application_id = var.create_fabric_resources ? try(fabric_workspace.this[0].identity.application_id, "") : try(data.external.workspace_identity[0].result.applicationId, "")
  effective_workspace_identity_principal_id   = var.create_fabric_resources ? try(fabric_workspace.this[0].identity.service_principal_id, "") : try(data.external.workspace_identity[0].result.servicePrincipalId, "")

  # ===========================================================================
  # Derived SQL endpoint for private link (existing logic, now using effective values)
  # ===========================================================================

  # Strip the public datawarehouse suffix from the original endpoint.
  fabric_host_root = trimsuffix(local.effective_sql_endpoint, ".datawarehouse.fabric.microsoft.com")

  # Per Doc 1: prefix the first two chars of the workspace ID with `z`
  # and insert as a subdomain, then re-append the warehouse-suffixed host.
  workspace_id_prefix = substr(local.effective_workspace_id, 0, 2)

  fabric_private_sql_endpoint = "${local.fabric_host_root}.z${local.workspace_id_prefix}.datawarehouse.fabric.microsoft.com;database=${var.fabric_warehouse_name}"

  # Synthetic resource ID Microsoft Fabric uses for trusted-workspace ACL rules.
  # The subscription is always all-zeros and the resource group is literally "Fabric".
  fabric_workspace_trusted_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Fabric/providers/Microsoft.Fabric/workspaces/${local.effective_workspace_id}"

  # Back-compat aliases — preserved because outputs.tf and other files reference
  # these by their original names.
  workspace_identity_application_id = local.effective_workspace_identity_application_id
  workspace_identity_principal_id   = local.effective_workspace_identity_principal_id
}
