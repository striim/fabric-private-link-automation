resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_storage_account" "this" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true

  # Created with public access ON so this Terraform run can provision the
  # container. storage-acls.tf flips publicNetworkAccess to Disabled after
  # the container, RBAC, and trusted-workspace ACL are in place.
  public_network_access_enabled = true

  tags = var.tags

  # azapi_update_resource.storage_acls_and_public_access owns network_acls
  # and public_network_access at apply time. Ignoring these here prevents
  # the azurerm provider from trying to revert them on every plan.
  lifecycle {
    ignore_changes = [
      public_network_access_enabled,
      network_rules,
    ]
  }
}

# Container is managed via azapi (ARM control plane) instead of azurerm.
# The azurerm provider manages containers through the blob data plane
# (*.blob.core.windows.net), which becomes unreachable once
# publicNetworkAccess is Disabled — every subsequent plan/apply would fail
# on refresh with a 403. azapi uses ARM throughout and is unaffected.
resource "azapi_resource" "staging" {
  type      = "Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01"
  name      = var.container_name
  parent_id = "${azurerm_storage_account.this.id}/blobServices/default"

  body = jsonencode({
    properties = {
      publicAccess                = "None"
      defaultEncryptionScope      = "$account-encryption-key"
      denyEncryptionScopeOverride = false
    }
  })
}
