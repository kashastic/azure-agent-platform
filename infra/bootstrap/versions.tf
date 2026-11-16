terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.60"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

  # Local state on purpose: this stack creates the storage account that
  # holds every other stack's state. Keep terraform.tfstate safe (it is
  # gitignored), or migrate it into the new account with init -migrate-state.
}
