# Foundation: the cheap, long-lived layer. It stays up between sessions;
# the expensive AKS stack is built on top of it and destroyed after use.

data "azurerm_client_config" "current" {}

data "azurerm_subscription" "current" {}

# Created by infra/bootstrap. Looked up by name, not by hard-coded ID.
data "azurerm_user_assigned_identity" "github_build" {
  name                = "id-${var.project}-gh-build"
  resource_group_name = "rg-${var.project}-tfstate"
}

resource "azurerm_resource_group" "core" {
  name     = "rg-${local.name}-core"
  location = var.location
  tags     = local.tags
}

module "guardrails" {
  source = "../../../modules/guardrails"

  name_prefix       = "${local.name}-core"
  resource_group_id = azurerm_resource_group.core.id
  allowed_locations = [var.location]
  required_tags     = local.required_tags
}

module "network" {
  source = "../../../modules/network"

  name                = "vnet-${local.name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.core.name
  address_space       = ["10.10.0.0/16"]
  tags                = local.tags

  # AKS nodes only; pods use the overlay range. The second subnet is
  # reserved for private endpoints (Key Vault, registry) in a later step.
  subnets = {
    "snet-aks"               = { address_prefixes = ["10.10.0.0/22"] }
    "snet-private-endpoints" = { address_prefixes = ["10.10.8.0/24"] }
  }
}

module "log_analytics" {
  source = "../../../modules/log-analytics"

  name                = "log-${local.name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.core.name
  tags                = local.tags
}

module "key_vault" {
  source = "../../../modules/key-vault"

  name                       = "kv-${local.name}-${var.suffix}"
  location                   = var.location
  resource_group_name        = azurerm_resource_group.core.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  log_analytics_workspace_id = module.log_analytics.id
  tags                       = local.tags

  secrets_officer_principal_ids = { for id in local.platform_admins : id => id }
}

module "container_registry" {
  source = "../../../modules/container-registry"

  name                = "acr${local.unique}"
  location            = var.location
  resource_group_name = azurerm_resource_group.core.name
  tags                = local.tags

  push_principal_ids = {
    github-build = data.azurerm_user_assigned_identity.github_build.principal_id
  }
}

# EURAG's workload identity lives here, not in the AKS stack, so its client
# ID stays the same when the cluster is destroyed and rebuilt. The AKS stack
# only adds the federated credential that trusts the current cluster.
resource "azurerm_user_assigned_identity" "eurag" {
  name                = "id-${local.name}-eurag"
  location            = var.location
  resource_group_name = azurerm_resource_group.core.name
  tags                = local.tags
}

resource "azurerm_role_assignment" "eurag_secrets_user" {
  scope                = module.key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.eurag.principal_id
  principal_type       = "ServicePrincipal"
}

# Subscription scope on purpose: AKS node VMs and disks are billed to the
# node resource group, which a resource-group budget would miss.
resource "azurerm_consumption_budget_subscription" "monthly" {
  count = var.alert_email == "" ? 0 : 1

  name            = "budget-${local.name}"
  subscription_id = data.azurerm_subscription.current.id
  amount          = var.monthly_budget
  time_grain      = "Monthly"

  time_period {
    start_date = var.budget_start_date
  }

  notification {
    enabled        = true
    threshold      = 50
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = [var.alert_email]
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    threshold_type = "Forecasted"
    contact_emails = [var.alert_email]
  }
}
