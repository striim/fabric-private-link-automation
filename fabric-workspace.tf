# Provision Workspace Identity on an EXISTING Fabric workspace via REST API.
#
# Used only when attaching to a pre-existing workspace (create_fabric_resources = false).
# When the module is creating the workspace itself (fabric-resources.tf), the
# fabric_workspace resource provisions the identity inline via its `identity`
# block — see local.effective_workspace_identity_* in locals.tf.
#
# Why not the microsoft/fabric provider for the existing-workspace path? The
# fabric_workspace resource manages the entire workspace lifecycle, which
# requires terraform import before apply. Calling provisionIdentity directly
# is idempotent — repeated calls when the identity already exists return 4xx,
# which we tolerate via `|| true`.
resource "null_resource" "provision_workspace_identity" {
  count = var.enable_fabric_workspace_config && !var.create_fabric_resources ? 1 : 0

  triggers = {
    workspace_id = var.fabric_workspace_id
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      az rest --method POST \
        --url "https://api.fabric.microsoft.com/v1/workspaces/${var.fabric_workspace_id}/provisionIdentity" \
        --resource "https://api.fabric.microsoft.com" \
        > /dev/null 2>&1 || true
    EOT
  }
}

# Read back the Workspace Identity's Entra object IDs from the workspace GET.
# Exposes applicationId (the SP's App ID) and servicePrincipalId (the SP's
# Entra Object ID, used as principal_id in role assignments).
#
# Skipped in bootstrap mode — see local.effective_workspace_identity_* which
# reads directly from the fabric_workspace resource's inline identity.
data "external" "workspace_identity" {
  count = var.enable_fabric_workspace_config && !var.create_fabric_resources ? 1 : 0

  program = [
    "bash", "-c",
    "az rest --method GET --url 'https://api.fabric.microsoft.com/v1/workspaces/${var.fabric_workspace_id}' --resource 'https://api.fabric.microsoft.com' | jq '{ applicationId: (.workspaceIdentity.applicationId // \"\"), servicePrincipalId: (.workspaceIdentity.servicePrincipalId // \"\") }'"
  ]

  depends_on = [null_resource.provision_workspace_identity]
}
