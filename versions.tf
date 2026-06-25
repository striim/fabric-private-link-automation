terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.110.0, < 4.0.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 2.50.0, < 3.0.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = ">= 1.13.0, < 2.0.0"
    }
    fabric = {
      source  = "microsoft/fabric"
      version = ">= 0.0.1, < 2.0.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.11.0, < 1.0.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.0, < 4.0.0"
    }
    external = {
      source  = "hashicorp/external"
      version = ">= 2.3.0, < 3.0.0"
    }
  }
}
