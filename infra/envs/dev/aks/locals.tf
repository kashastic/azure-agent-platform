locals {
  name   = "${var.project}-${var.env}"
  unique = "${var.project}${var.env}${var.suffix}"

  required_tags = ["owner", "env", "cost-center"]

  tags = {
    project     = var.project
    env         = var.env
    owner       = var.owner
    cost-center = var.cost_center
    managed-by  = "terraform"
    stack       = "aks"
  }

  platform_admins = length(var.platform_admin_object_ids) > 0 ? var.platform_admin_object_ids : [data.azurerm_client_config.current.object_id]

  # Same file as the access stack and the team-namespaces chart.
  teams_file = yamldecode(file("${path.module}/../../../../platform/teams.yaml"))

  teams = {
    for team, spec in local.teams_file.teams : team => {
      namespace = spec.namespace
      k8s_role  = try(spec.k8s_role, "reader")
    }
  }

  # Namespace-scoped Azure RBAC roles. "cluster-admin" teams get the
  # cluster-wide admin role instead (see main.tf).
  namespace_roles = {
    reader = "Azure Kubernetes Service RBAC Reader"
    writer = "Azure Kubernetes Service RBAC Writer"
    admin  = "Azure Kubernetes Service RBAC Admin"
  }

  namespaced_teams    = { for team, spec in local.teams : team => spec if contains(keys(local.namespace_roles), spec.k8s_role) }
  cluster_admin_teams = { for team, spec in local.teams : team => spec if spec.k8s_role == "cluster-admin" }
  alert_action_groups = azurerm_monitor_action_group.platform[*].id
}
