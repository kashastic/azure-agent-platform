# Subscription from ARM_SUBSCRIPTION_ID; resource providers are registered once by hand (see the runbook).
provider "azurerm" {
  features {}

  resource_provider_registrations = "none"
}

# Read-only here: looks up the team groups created by the access stack.
provider "azuread" {}
