# =====================================================================
# Required inputs: identifiers for existing customer resources
# =====================================================================

variable "subscription_id" {
  description = "Azure subscription that hosts the module deployment."
  type        = string
}

variable "tenant_id" {
  description = "Microsoft Entra tenant. Must match the Fabric tenant."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the storage account and Private Link Service."
  type        = string
}

variable "location" {
  description = "Azure region for the storage account."
  type        = string
}

# =====================================================================
# Required inputs: naming for new resources
# =====================================================================

variable "storage_account_name" {
  description = "ADLS Gen2 storage account name. Must be globally unique, 3-24 lowercase alphanumeric."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "storage_account_name must be 3-24 characters, lowercase letters and digits only."
  }
}

variable "container_name" {
  description = "Blob container name used by Striim as the staging area."
  type        = string
}

variable "app_registration_name" {
  description = "Display name for the Entra ID app registration created for the SPN."
  type        = string
}

variable "fabric_workspace_id" {
  description = "Existing Fabric workspace ID (GUID). Leave empty when create_fabric_resources = true — the module derives it from the workspace it creates."
  type        = string
  default     = ""

  validation {
    condition     = var.fabric_workspace_id == "" || can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.fabric_workspace_id))
    error_message = "fabric_workspace_id must be a valid GUID (or empty when create_fabric_resources = true)."
  }
}

variable "fabric_warehouse_name" {
  description = "Warehouse name. When create_fabric_resources = true, this is the display name for the new warehouse; otherwise it must match the existing warehouse used in the derived SQL endpoint."
  type        = string
}

variable "fabric_sql_endpoint" {
  description = "Original public SQL endpoint of the existing warehouse, e.g. y2g6...datawarehouse.fabric.microsoft.com. Leave empty when create_fabric_resources = true — the module derives it from the warehouse's connection_string."
  type        = string
  default     = ""

  validation {
    condition     = var.fabric_sql_endpoint == "" || endswith(var.fabric_sql_endpoint, ".datawarehouse.fabric.microsoft.com")
    error_message = "fabric_sql_endpoint must end with .datawarehouse.fabric.microsoft.com (or be empty when create_fabric_resources = true)."
  }
}

variable "pls_resource_name" {
  description = "Name of the Microsoft.Fabric/privateLinkServicesForFabric resource."
  type        = string
}

# =====================================================================
# Optional inputs: bootstrap-mode (blank-slate customer)
# =====================================================================

variable "create_fabric_resources" {
  description = "When true, the module creates the Fabric workspace + warehouse (and uses its inline Workspace Identity) instead of attaching to existing ones. Requires fabric_capacity_id and fabric_workspace_name."
  type        = bool
  default     = false
}

variable "fabric_capacity_id" {
  description = "Fabric capacity GUID (NOT the Azure resource ID). This is the capacity's internal Fabric ID returned by `GET https://api.fabric.microsoft.com/v1/capacities`. Required when create_fabric_resources = true. The capacity must be F2 or higher and the deploying principal must be a capacity admin."
  type        = string
  default     = ""

  validation {
    condition     = var.fabric_capacity_id == "" || can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.fabric_capacity_id))
    error_message = "fabric_capacity_id must be a UUID (Fabric capacity GUID, not the Azure resource ID). Find it via: az rest --method GET --url 'https://api.fabric.microsoft.com/v1/capacities' --resource 'https://api.fabric.microsoft.com'"
  }
}

variable "fabric_workspace_name" {
  description = "Display name for the new Fabric workspace. Required when create_fabric_resources = true."
  type        = string
  default     = ""
}

variable "block_workspace_public_access" {
  description = "When true (and create_fabric_resources = true), attempt to disable public network access on the new workspace via a Fabric REST shim. The exact API path is still being verified — see fabric-resources.tf TBD note."
  type        = bool
  default     = true
}

# =====================================================================
# Optional inputs: behavior toggles
# =====================================================================

variable "enable_fabric_workspace_config" {
  description = "Enable Workspace Identity provisioning and Fabric workspace role assignments via the Fabric provider."
  type        = bool
  default     = true
}

variable "auto_approve_pe_connections" {
  description = "Auto-approve inbound Striim private endpoint connections on the storage account and the Fabric PLS. Leave false during initial setup — the customer flow approves the Fabric PE manually via `az rest` after Striim creates it (see RUNBOOK Phase 3)."
  type        = bool
  default     = false
}

variable "disable_storage_public_network" {
  description = "Disable public network access on the storage account after provisioning."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to all created Azure resources."
  type        = map(string)
  default     = {}
}

variable "client_secret_rotation_days" {
  description = "Lifetime in days of the SPN client secret."
  type        = number
  default     = 365
}
