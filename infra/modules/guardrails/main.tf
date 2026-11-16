# Built-in Azure Policy definitions, assigned at resource group scope.
# Both use the "deny" effect: a non-compliant deployment fails instead of
# being reported after the fact.
locals {
  allowed_locations_definition = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"
  require_tag_definition       = "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99"
}

resource "azurerm_resource_group_policy_assignment" "allowed_locations" {
  name                 = "${var.name_prefix}-allowed-locations"
  display_name         = "Allowed locations (${var.name_prefix})"
  description          = "Resources in this resource group may only be created in approved regions (data residency)."
  resource_group_id    = var.resource_group_id
  policy_definition_id = local.allowed_locations_definition

  parameters = jsonencode({
    listOfAllowedLocations = {
      value = var.allowed_locations
    }
  })
}

resource "azurerm_resource_group_policy_assignment" "required_tag" {
  for_each = toset(var.required_tags)

  name                 = "${var.name_prefix}-tag-${each.value}"
  display_name         = "Require tag '${each.value}' (${var.name_prefix})"
  description          = "Every taggable resource must carry the '${each.value}' tag, so cost and ownership are always known."
  resource_group_id    = var.resource_group_id
  policy_definition_id = local.require_tag_definition

  parameters = jsonencode({
    tagName = {
      value = each.value
    }
  })
}
