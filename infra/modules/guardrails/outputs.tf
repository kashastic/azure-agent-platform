output "policy_assignment_ids" {
  description = "IDs of the policy assignments created by this module."
  value = concat(
    [azurerm_resource_group_policy_assignment.allowed_locations.id],
    [for assignment in azurerm_resource_group_policy_assignment.required_tag : assignment.id],
  )
}
