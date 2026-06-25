# Microsoft.Fabric/privateLinkServicesForFabric — the Azure ARM resource
# that fronts the Fabric workspace for inbound private endpoint connections
# from the Striim control plane. Location is fixed to "global" per the
# resource type contract.
resource "azapi_resource" "fabric_pls" {
  type      = "Microsoft.Fabric/privateLinkServicesForFabric@2024-06-01"
  name      = var.pls_resource_name
  parent_id = azurerm_resource_group.this.id
  location  = "global"

  # azapi v1.15.0's local schema cache doesn't include the
  # Microsoft.Fabric/privateLinkServicesForFabric resource type yet.
  # The actual ARM API will validate this at apply time.
  schema_validation_enabled = false

  body = jsonencode({
    properties = {
      tenantId    = var.tenant_id
      workspaceId = local.effective_workspace_id
    }
  })

  tags = var.tags

  depends_on = [null_resource.fabric_rp_registration]
}
