# =====================================================================
# SPN credentials — paste into the Striim Fabric Warehouse connection profile
# =====================================================================

output "spn_application_id" {
  description = "Application (client) ID of the Entra ID app registration. Used as the Client ID in Striim's Microsoft Entra Service Principal auth."
  value       = azuread_application.spn.client_id
}

output "spn_client_secret" {
  description = "Client secret value of the SPN. Used as the Client Secret in Striim's Microsoft Entra Service Principal auth."
  value       = azuread_application_password.spn.value
  sensitive   = true
}

output "spn_object_id" {
  description = "Entra Object ID of the SPN."
  value       = azuread_service_principal.spn.object_id
}

# =====================================================================
# Storage — for Striim ADLS Gen2 connection profile and PE creation
# =====================================================================

output "storage_account_name" {
  description = "Name of the ADLS Gen2 staging storage account."
  value       = azurerm_storage_account.this.name
}

output "storage_account_id" {
  description = "Resource ID of the storage account. Use as the Service Alias when creating the Striim private endpoint to ADLS Gen2."
  value       = azurerm_storage_account.this.id
}

output "storage_container_url" {
  description = "Full URL of the staging container."
  value       = "https://${azurerm_storage_account.this.name}.blob.core.windows.net/${azapi_resource.staging.name}"
}

# =====================================================================
# Fabric — workspace, warehouse, and effective SQL endpoint
# (always present; when create_fabric_resources = false, these echo the
# input values so the customer has a single place to read what's wired up)
# =====================================================================

output "fabric_workspace_id" {
  description = "Fabric workspace ID in use — either the newly-created workspace (bootstrap mode) or the input value (attach-to-existing mode)."
  value       = local.effective_workspace_id
}

output "fabric_warehouse_id" {
  description = "Fabric warehouse resource ID. Empty when attach-to-existing mode (the input only provides the warehouse name)."
  value       = var.create_fabric_resources ? fabric_warehouse.this[0].id : ""
}

output "fabric_sql_endpoint_effective" {
  description = "Public SQL endpoint hostname being used as the base for derivation. Either the warehouse's connection_string (bootstrap mode) or the fabric_sql_endpoint input."
  value       = local.effective_sql_endpoint
}

# =====================================================================
# Fabric — Private Link Service and Workspace Identity
# =====================================================================

output "fabric_pls_id" {
  description = "Resource ID of the Microsoft.Fabric/privateLinkServicesForFabric resource. Use as the Service Alias when creating the Striim private endpoint to Fabric (target sub-resource: workspace)."
  value       = azapi_resource.fabric_pls.id
}

output "workspace_identity_object_id" {
  description = "Entra Object ID of the Fabric Workspace Identity service principal."
  value       = local.effective_workspace_identity_principal_id
}

output "workspace_identity_application_id" {
  description = "Entra Application ID of the Fabric Workspace Identity."
  value       = local.effective_workspace_identity_application_id
}

# =====================================================================
# Derived endpoint — pastes directly into the Striim Fabric Warehouse profile
# =====================================================================

output "fabric_private_sql_endpoint" {
  description = "Derived private SQL endpoint string. Paste into the SQL Connection String field of the Striim Fabric Warehouse connection profile to switch traffic from public to private."
  value       = local.fabric_private_sql_endpoint
}
