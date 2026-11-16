resource "azurerm_container_registry" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku

  # No registry passwords: pushes and pulls use Entra ID identities with
  # AcrPush and AcrPull role assignments.
  admin_enabled = false

  tags = var.tags
}

resource "azurerm_role_assignment" "push" {
  for_each = var.push_principal_ids

  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPush"
  principal_id         = each.value
  principal_type       = "ServicePrincipal"
}
