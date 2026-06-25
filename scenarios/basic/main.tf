# All customer-specific values come from terraform.tfvars (or terraform.tfvars.example).
# See terraform.tfvars.example for placeholder values and inline descriptions.

variable "subscription_id" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "resource_group_name" {
  description = "Name of the Azure resource group the module will create. Must not already exist."
  type        = string
}

variable "location" {
  description = "Azure region. Must match the region of your Fabric capacity."
  type        = string
}

variable "storage_account_name" {
  description = "Globally unique storage account name. 3-24 lowercase alphanumeric."
  type        = string
}

variable "app_registration_name" {
  description = "Display name for the new Entra ID app registration."
  type        = string
}

variable "fabric_workspace_id" {
  description = "Your existing Fabric workspace ID (GUID)."
  type        = string
}

variable "fabric_warehouse_name" {
  description = "Your existing Fabric warehouse name."
  type        = string
}

variable "fabric_sql_endpoint" {
  description = "Your existing warehouse public SQL endpoint, e.g. xxx.datawarehouse.fabric.microsoft.com."
  type        = string
}

variable "pls_resource_name" {
  description = "Name for the Microsoft.Fabric/privateLinkServicesForFabric resource."
  type        = string
}

module "striim_fabric_private_link" {
  source = "../.."

  subscription_id       = var.subscription_id
  tenant_id             = var.tenant_id
  resource_group_name   = var.resource_group_name
  location              = var.location
  storage_account_name  = var.storage_account_name
  container_name        = "striim-staging"
  app_registration_name = var.app_registration_name

  # Attach to an existing Fabric workspace + warehouse.
  fabric_workspace_id   = var.fabric_workspace_id
  fabric_warehouse_name = var.fabric_warehouse_name
  fabric_sql_endpoint   = var.fabric_sql_endpoint

  pls_resource_name = var.pls_resource_name

  # Leave false. The customer flow approves the Fabric PE via `az rest`
  # in CUSTOMER_GUIDE.md Phase 3 — no need to flip this. Flip to true only if
  # you specifically want terraform to drive the approval.
  auto_approve_pe_connections = false
}

# -----------------------------------------------------------------
# Outputs to paste into the Striim UI
# -----------------------------------------------------------------

output "fabric_private_sql_endpoint" {
  description = "→ Striim Fabric Warehouse connection profile, SQL Connection String field."
  value       = module.striim_fabric_private_link.fabric_private_sql_endpoint
}

output "spn_application_id" {
  description = "→ Striim Fabric Warehouse connection profile, Client ID field."
  value       = module.striim_fabric_private_link.spn_application_id
}

output "spn_client_secret" {
  description = "→ Striim Fabric Warehouse connection profile, Client Secret field. Retrieve with: terraform output -raw spn_client_secret"
  value       = module.striim_fabric_private_link.spn_client_secret
  sensitive   = true
}

# -----------------------------------------------------------------
# Outputs to paste when creating Striim-side private endpoints
# -----------------------------------------------------------------

output "storage_account_id" {
  description = "→ Striim 'Create Private Endpoint' dialog, Service Alias field (target sub-resource: blob)."
  value       = module.striim_fabric_private_link.storage_account_id
}

output "fabric_pls_id" {
  description = "→ Striim 'Create Private Endpoint' dialog, Service Alias field (target sub-resource: workspace)."
  value       = module.striim_fabric_private_link.fabric_pls_id
}

# -----------------------------------------------------------------
# Outputs to paste into the Striim ADLS Gen2 connection profile
# -----------------------------------------------------------------

output "storage_account_name" {
  description = "→ Striim ADLS Gen2 connection profile, Azure Account Name field."
  value       = module.striim_fabric_private_link.storage_account_name
}

output "storage_container_url" {
  description = "Full URL of the staging container."
  value       = module.striim_fabric_private_link.storage_container_url
}
