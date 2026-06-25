resource "azapi_update_resource" "storage_acls_and_public_access" {
  type        = "Microsoft.Storage/storageAccounts@2023-01-01"
  resource_id = azurerm_storage_account.this.id

  body = jsonencode({
    properties = {
      networkAcls = {
        bypass        = "AzureServices"
        defaultAction = "Deny"
        resourceAccessRules = [
          {
            tenantId   = var.tenant_id
            resourceId = local.fabric_workspace_trusted_resource_id
          }
        ]
      }
      publicNetworkAccess = var.disable_storage_public_network ? "Disabled" : "Enabled"
    }
  })

  depends_on = [
    azapi_resource.staging,
    azurerm_role_assignment.spn_storage_blob,
    azurerm_role_assignment.workspace_identity_storage_blob,
  ]
}
