resource "azurerm_key_vault" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  # Access is Azure RBAC only (no access policies), so it is granted and
  # audited the same way as every other role in the platform.
  enable_rbac_authorization = true

  soft_delete_retention_days    = var.soft_delete_retention_days
  purge_protection_enabled      = var.purge_protection_enabled
  public_network_access_enabled = true

  tags = var.tags
}

resource "azurerm_role_assignment" "secrets_officer" {
  for_each = var.secrets_officer_principal_ids

  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = each.value
}

# Every secret read and write lands in Log Analytics (who, when, from where).
resource "azurerm_monitor_diagnostic_setting" "audit" {
  name                       = "diag-${var.name}"
  target_resource_id         = azurerm_key_vault.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AuditEvent"
  }
}
