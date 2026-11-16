data "azurerm_client_config" "current" {}

data "azurerm_subscription" "current" {}

locals {
  tags = {
    project     = var.project
    env         = var.env
    owner       = var.owner
    cost-center = var.cost_center
    managed-by  = "terraform"
    stack       = "bootstrap"
  }
}

# ---------------------------------------------------------------------------
# Remote state
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "state" {
  name     = "rg-${var.project}-tfstate"
  location = var.location
  tags     = local.tags
}

resource "azurerm_storage_account" "state" {
  name                            = "st${var.project}tf${var.suffix}"
  resource_group_name             = azurerm_resource_group.state.name
  location                        = azurerm_resource_group.state.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = local.tags

  # Versioning and soft delete: a corrupted or deleted state file can be
  # restored from an earlier version.
  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 14
    }

    container_delete_retention_policy {
      days = 14
    }
  }
}

resource "azurerm_storage_container" "state" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}

# The backend signs in with Entra ID (use_azuread_auth), so the person
# running Terraform needs a data-plane role, not the storage account key.
resource "azurerm_role_assignment" "state_deployer" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "local_file" "backend_config" {
  filename        = "${path.module}/../envs/${var.env}/backend.hcl"
  file_permission = "0644"
  content         = <<-EOT
    # Written by infra/bootstrap. Every stack runs: terraform init -backend-config=../backend.hcl
    resource_group_name  = "${azurerm_resource_group.state.name}"
    storage_account_name = "${azurerm_storage_account.state.name}"
    container_name       = "${azurerm_storage_container.state.name}"
    use_azuread_auth     = true
  EOT
}

# ---------------------------------------------------------------------------
# GitHub Actions identities (OIDC federation, no stored secrets)
#   plan:  read-only, used by pull requests
#   apply: can change infrastructure, only from the approved "dev" environment
#   build: can only push images to the registry, only from main
# ---------------------------------------------------------------------------

locals {
  github_identities = {
    plan  = "repo:${var.github_repository}:pull_request"
    apply = "repo:${var.github_repository}:environment:${var.env}"
    build = "repo:${var.github_repository}:ref:refs/heads/main"
  }
}

resource "azurerm_user_assigned_identity" "github" {
  for_each = local.github_identities

  name                = "id-${var.project}-gh-${each.key}"
  location            = azurerm_resource_group.state.location
  resource_group_name = azurerm_resource_group.state.name
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "github" {
  for_each = local.github_identities

  name                = "github-${each.key}"
  resource_group_name = azurerm_resource_group.state.name
  parent_id           = azurerm_user_assigned_identity.github[each.key].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = each.value
}

# A second credential on the plan identity, so a manual plan from main works
# too. Created after the first one: Azure rejects parallel writes of
# federated credentials on the same identity.
resource "azurerm_federated_identity_credential" "plan_main" {
  name                = "github-plan-main"
  resource_group_name = azurerm_resource_group.state.name
  parent_id           = azurerm_user_assigned_identity.github["plan"].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:${var.github_repository}:ref:refs/heads/main"

  depends_on = [azurerm_federated_identity_credential.github]
}

resource "azurerm_role_assignment" "plan_reader" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.github["plan"].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "plan_state_reader" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.github["plan"].principal_id
  principal_type       = "ServicePrincipal"
}

# Lab trade-off: subscription scope. In a shared subscription this would be
# scoped to the platform resource groups, and the RBAC administrator role
# limited with a condition to the few roles the platform hands out.
resource "azurerm_role_assignment" "apply_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.github["apply"].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "apply_rbac_admin" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = azurerm_user_assigned_identity.github["apply"].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "apply_state" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.github["apply"].principal_id
  principal_type       = "ServicePrincipal"
}
