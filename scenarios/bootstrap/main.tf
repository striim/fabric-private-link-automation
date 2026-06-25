# Bootstrap example — for customers starting from a blank slate
# (no existing Fabric workspace / warehouse / storage account).
#
# This example sets create_fabric_resources = true, which causes the module to:
#   - Create a new Fabric workspace attached to the supplied capacity
#   - Create a new Fabric warehouse inside that workspace
#   - Provision the workspace identity inline (no separate REST call)
#   - Disable public network access on the workspace (best-effort; see TBD in
#     fabric-resources.tf)
#   - Create the ADLS Gen2 storage account, SPN, RBAC, PLS, and approval logic
#     as in the basic example
#
# Prerequisite: the customer must have a Microsoft.Fabric/capacities resource
# (F2 or higher) already provisioned in their subscription, and the deploying
# principal must have at minimum Fabric capacity admin rights on it.
#
# If the customer already has a Fabric workspace + warehouse, use scenarios/basic
# instead — that path attaches to the existing workspace and skips the
# fabric_workspace / fabric_warehouse resources.

# All customer-specific values come from terraform.tfvars (or terraform.tfvars.example).
# See terraform.tfvars.example for placeholder values and inline descriptions.

variable "subscription_id" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "fabric_capacity_id" {
  description = "Fabric capacity GUID (NOT the Azure resource ID). Find with: az rest --method GET --url 'https://api.fabric.microsoft.com/v1/capacities' --resource 'https://api.fabric.microsoft.com' | jq '.value[].id'"
  type        = string
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

variable "fabric_workspace_name" {
  description = "Display name for the new Fabric workspace."
  type        = string
}

variable "fabric_warehouse_name" {
  description = "Display name for the new Fabric warehouse inside the workspace."
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

  # Bootstrap inputs: workspace + warehouse get created by the module.
  # fabric_workspace_id and fabric_sql_endpoint are derived from the created
  # resources — leave empty when create_fabric_resources = true.
  create_fabric_resources = true
  fabric_capacity_id      = var.fabric_capacity_id
  fabric_workspace_name   = var.fabric_workspace_name
  fabric_warehouse_name   = var.fabric_warehouse_name

  pls_resource_name = var.pls_resource_name

  auto_approve_pe_connections = false
}

# -----------------------------------------------------------------
# Outputs to paste into the Striim UI after terraform apply completes
# -----------------------------------------------------------------

output "fabric_workspace_id" {
  description = "ID of the newly-created Fabric workspace."
  value       = module.striim_fabric_private_link.fabric_workspace_id
}

output "fabric_warehouse_id" {
  description = "Resource ID of the newly-created Fabric warehouse."
  value       = module.striim_fabric_private_link.fabric_warehouse_id
}

output "fabric_sql_endpoint_effective" {
  description = "Public SQL endpoint of the warehouse (used as the base for the private-endpoint-derived hostname)."
  value       = module.striim_fabric_private_link.fabric_sql_endpoint_effective
}

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

output "storage_account_id" {
  description = "→ Striim 'Create Private Endpoint' dialog, Service Alias field (target sub-resource: blob)."
  value       = module.striim_fabric_private_link.storage_account_id
}

output "fabric_pls_id" {
  description = "→ Striim 'Create Private Endpoint' dialog, Service Alias field (target sub-resource: workspace)."
  value       = module.striim_fabric_private_link.fabric_pls_id
}

output "storage_account_name" {
  description = "→ Striim ADLS Gen2 connection profile, Azure Account Name field."
  value       = module.striim_fabric_private_link.storage_account_name
}
