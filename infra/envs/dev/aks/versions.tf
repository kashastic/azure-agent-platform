terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.60"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }

  # Partial configuration: the storage account comes from ../backend.hcl.
  backend "azurerm" {
    key = "dev/aks.tfstate"
  }
}
