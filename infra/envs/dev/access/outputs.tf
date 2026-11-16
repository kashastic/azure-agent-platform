output "team_group_ids" {
  description = "Entra ID group object IDs, keyed by team."
  value       = { for team, group in azuread_group.team : team => group.object_id }
}
