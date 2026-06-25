resource "azurerm_role_assignment" "spn_storage_blob" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.spn.object_id
  principal_type       = "ServicePrincipal"
}

# Workspace Identity role assignment on the storage account.
# Defined here (vs fabric-rbac.tf) because the scope is storage, not Fabric.
# Conditional on enable_fabric_workspace_config — the Workspace Identity
# is provisioned by fabric-workspace.tf.
resource "azurerm_role_assignment" "workspace_identity_storage_blob" {
  count = var.enable_fabric_workspace_config ? 1 : 0

  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = local.workspace_identity_principal_id
  principal_type       = "ServicePrincipal"
}
