# Access: one Entra ID security group per team in platform/teams.yaml.
# Cluster permissions for these groups are granted by the AKS stack, because
# they are scoped to the cluster and come and go with it.

data "azuread_user" "member" {
  for_each = local.members

  user_principal_name = each.value
}

resource "azuread_group" "team" {
  for_each = local.teams

  display_name            = "grp-${var.project}-${each.key}"
  description             = "${each.value.description}. Managed from platform/teams.yaml."
  security_enabled        = true
  prevent_duplicate_names = true
  members                 = [for upn in each.value.members : data.azuread_user.member[upn].object_id]
}

data "azurerm_key_vault" "core" {
  name                = "kv-${local.name}-${var.suffix}"
  resource_group_name = "rg-${local.name}-core"
}

resource "azurerm_role_assignment" "team_keyvault_secrets" {
  for_each = { for team, spec in local.teams : team => spec if spec.keyvault_secrets_read }

  scope                = data.azurerm_key_vault.core.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azuread_group.team[each.key].object_id
  principal_type       = "Group"
}
