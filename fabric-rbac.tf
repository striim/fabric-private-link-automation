# Workspace-scoped role assignments via the microsoft/fabric provider.
# The fabric_workspace_role_assignment resource accepts a workspace_id input
# and does not require the workspace itself to be managed as a Terraform
# resource — so no import step is needed.
#
# Schema assumption: principal is an object { id, type }. If v0.1 of the
# provider exposes a different shape, this falls back to az rest POST against
# /workspaces/{id}/roleAssignments.

resource "fabric_workspace_role_assignment" "spn_contributor" {
  count = var.enable_fabric_workspace_config ? 1 : 0

  workspace_id = local.effective_workspace_id
  role         = "Contributor"

  principal = {
    id   = azuread_service_principal.spn.object_id
    type = "ServicePrincipal"
  }
}

resource "fabric_workspace_role_assignment" "workspace_identity_contributor" {
  count = var.enable_fabric_workspace_config ? 1 : 0

  workspace_id = local.effective_workspace_id
  role         = "Contributor"

  principal = {
    id   = local.workspace_identity_principal_id
    type = "ServicePrincipal"
  }
}
