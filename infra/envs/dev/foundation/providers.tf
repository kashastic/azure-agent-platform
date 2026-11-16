# Subscription from ARM_SUBSCRIPTION_ID; resource providers are registered once by hand (see the runbook).
provider "azurerm" {
  features {
    # Manage the data storage account through the management API only. Its
    # shared keys are off, and nothing here needs blob-level access.
    storage {
      data_plane_available = false
    }
  }

  resource_provider_registrations = "none"
}
