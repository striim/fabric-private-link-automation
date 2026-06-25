# ============================================================================
# Bootstrap mode — when create_fabric_resources = true, this module creates
# the Fabric workspace and warehouse from scratch (blank-slate customer).
#
# When create_fabric_resources = false (default), customers attach to an
# existing workspace/warehouse via the fabric_workspace_id and
# fabric_sql_endpoint inputs, and these resources are skipped.
#
# The downstream resources (fabric-pls.tf, fabric-rbac.tf, storage-acls.tf,
# locals.tf) read local.effective_workspace_id / local.effective_sql_endpoint
# so they don't need to branch on the flag.
# ============================================================================

resource "fabric_workspace" "this" {
  count = var.create_fabric_resources ? 1 : 0

  display_name = var.fabric_workspace_name
  capacity_id  = var.fabric_capacity_id

  # Inline workspace identity provisioning. When this block is present, the
  # provider creates and returns the identity's application_id and
  # service_principal_id directly — no need for the az rest provisionIdentity
  # workaround used in fabric-workspace.tf for the existing-workspace path.
  identity = {
    type = "SystemAssigned"
  }
}

resource "fabric_warehouse" "this" {
  count = var.create_fabric_resources ? 1 : 0

  display_name = var.fabric_warehouse_name
  workspace_id = fabric_workspace.this[0].id
}

# ============================================================================
# Workspace "block public network access" — disables public internet access
# on the new workspace, forcing all traffic via Private Link.
#
# API reference:
#   https://learn.microsoft.com/en-us/rest/api/fabric/core/workspaces/set-network-communication-policy
#
# Requires the Fabric tenant admin to have enabled the tenant setting
# "Configure workspace-level inbound network rules" — otherwise this call
# returns 403 InboundRestrictionNotEligible. The deploying identity must
# also be Admin on the workspace.
# ============================================================================
resource "null_resource" "block_workspace_public_access" {
  count = var.create_fabric_resources && var.block_workspace_public_access ? 1 : 0

  triggers = {
    workspace_id = fabric_workspace.this[0].id
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -e
      ws_id="${fabric_workspace.this[0].id}"
      az rest --method PUT \
        --url "https://api.fabric.microsoft.com/v1/workspaces/$${ws_id}/networking/communicationPolicy" \
        --resource "https://api.fabric.microsoft.com" \
        --body '{"inbound":{"publicAccessRules":{"defaultAction":"Deny"}}}'
    EOT
  }

  depends_on = [
    fabric_warehouse.this,
  ]
}
