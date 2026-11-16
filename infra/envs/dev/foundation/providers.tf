# Subscription from ARM_SUBSCRIPTION_ID; resource providers are registered once by hand (see the runbook).
provider "azurerm" {
  features {}

  resource_provider_registrations = "none"

  # The data storage account has shared keys turned off.
  storage_use_azuread = true
}
