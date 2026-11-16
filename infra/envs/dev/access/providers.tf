# Subscription from ARM_SUBSCRIPTION_ID; resource providers are registered once by hand (see the runbook).
provider "azurerm" {
  features {}

  resource_provider_registrations = "none"
}

# Signs in with the same Azure CLI session. Creating groups needs the
# Entra ID right to create security groups (on by default in a tenant you own).
provider "azuread" {}
