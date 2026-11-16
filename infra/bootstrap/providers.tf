# The subscription comes from ARM_SUBSCRIPTION_ID, so nothing account-specific
# is committed. Resource providers are registered once by hand (see the
# runbook) instead of letting every plan try to register dozens of them.
provider "azurerm" {
  features {}

  resource_provider_registrations = "none"
}
