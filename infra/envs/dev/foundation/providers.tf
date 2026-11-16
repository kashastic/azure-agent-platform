# Subscription from ARM_SUBSCRIPTION_ID; resource providers are registered once by hand (see the runbook).
provider "azurerm" {
  features {}

  resource_provider_registrations = "none"
}
