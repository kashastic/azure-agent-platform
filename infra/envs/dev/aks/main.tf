# AKS: the expensive layer. Destroy it after each session; everything it
# needs from the foundation is looked up by naming convention.

data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "core" {
  name = "rg-${local.name}-core"
}

data "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  virtual_network_name = "vnet-${local.name}"
  resource_group_name  = data.azurerm_resource_group.core.name
}

data "azurerm_log_analytics_workspace" "core" {
  name                = "log-${local.name}"
  resource_group_name = data.azurerm_resource_group.core.name
}

data "azurerm_container_registry" "core" {
  name                = "acr${local.unique}"
  resource_group_name = data.azurerm_resource_group.core.name
}

data "azurerm_user_assigned_identity" "eurag" {
  name                = "id-${local.name}-eurag"
  resource_group_name = data.azurerm_resource_group.core.name
}

# Created by the access stack from platform/teams.yaml.
data "azuread_group" "team" {
  for_each = local.teams

  display_name     = "grp-${var.project}-${each.key}"
  security_enabled = true
}

resource "azurerm_resource_group" "aks" {
  name     = "rg-${local.name}-aks"
  location = var.location
  tags     = local.tags
}

module "guardrails" {
  source = "../../../modules/guardrails"

  name_prefix       = "${local.name}-aks"
  resource_group_id = azurerm_resource_group.aks.id
  allowed_locations = [var.location]
  required_tags     = local.required_tags
}

module "aks" {
  source = "../../../modules/aks"

  name                       = "aks-${local.name}"
  location                   = var.location
  resource_group_name        = azurerm_resource_group.aks.name
  node_resource_group        = "rg-${local.name}-aks-nodes"
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  kubernetes_version         = var.kubernetes_version
  vm_size                    = var.node_vm_size
  node_count                 = var.node_count
  subnet_id                  = data.azurerm_subnet.aks.id
  acr_id                     = data.azurerm_container_registry.core.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.core.id
  tags                       = local.tags

  cluster_admin_principal_ids = merge(
    { for id in local.platform_admins : "admin-${id}" => id },
    { for team, spec in local.cluster_admin_teams : "team-${team}" => data.azuread_group.team[team].object_id },
  )
}

# ---------------------------------------------------------------------------
# Team access from platform/teams.yaml
# ---------------------------------------------------------------------------

# Azure RBAC scoped to one namespace: a team's group can work in its own
# namespace and nowhere else. The namespace itself is created by Argo CD.
resource "azurerm_role_assignment" "team_namespace" {
  for_each = local.namespaced_teams

  scope                = "${module.aks.id}/namespaces/${each.value.namespace}"
  role_definition_name = local.namespace_roles[each.value.k8s_role]
  principal_id         = data.azuread_group.team[each.key].object_id
  principal_type       = "Group"
}

# Lets team members download a kubeconfig. What they may do inside the
# cluster is decided by the namespace role above.
resource "azurerm_role_assignment" "team_cluster_user" {
  for_each = local.teams

  scope                = module.aks.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = data.azuread_group.team[each.key].object_id
  principal_type       = "Group"
}

# ---------------------------------------------------------------------------
# EURAG workload identity: trust tokens for the eurag service account
# issued by this cluster. No keys are stored anywhere.
# ---------------------------------------------------------------------------

resource "azurerm_federated_identity_credential" "eurag" {
  name      = "${module.aks.name}-${var.eurag_namespace}-${var.eurag_service_account}"
  parent_id = data.azurerm_user_assigned_identity.eurag.id
  audience  = ["api://AzureADTokenExchange"]
  issuer    = module.aks.oidc_issuer_url
  subject   = "system:serviceaccount:${var.eurag_namespace}:${var.eurag_service_account}"
}

# ---------------------------------------------------------------------------
# Alerts
# ---------------------------------------------------------------------------

resource "azurerm_monitor_action_group" "platform" {
  count = var.alert_email == "" ? 0 : 1

  name                = "ag-${local.name}-platform"
  resource_group_name = azurerm_resource_group.aks.name
  short_name          = "platform"
  tags                = local.tags

  email_receiver {
    name                    = "platform-oncall"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}

resource "azurerm_monitor_metric_alert" "node_cpu" {
  name                = "alert-${local.name}-node-cpu"
  resource_group_name = azurerm_resource_group.aks.name
  scopes              = [module.aks.id]
  description         = "Average node CPU above 80% for 15 minutes."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = local.tags

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_cpu_usage_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  dynamic "action" {
    for_each = local.alert_action_groups

    content {
      action_group_id = action.value
    }
  }
}

resource "azurerm_monitor_metric_alert" "node_memory" {
  name                = "alert-${local.name}-node-memory"
  resource_group_name = azurerm_resource_group.aks.name
  scopes              = [module.aks.id]
  description         = "Average node working-set memory above 85% for 15 minutes."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = local.tags

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_memory_working_set_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 85
  }

  dynamic "action" {
    for_each = local.alert_action_groups

    content {
      action_group_id = action.value
    }
  }
}

# EURAG's own docs record an out-of-memory kill on a 4 GB host. This catches
# that class of failure: any workload container restart in a 15-minute window.
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "pod_restarts" {
  name                 = "alert-${local.name}-pod-restarts"
  resource_group_name  = azurerm_resource_group.aks.name
  location             = var.location
  scopes               = [data.azurerm_log_analytics_workspace.core.id]
  description          = "A workload container restarted (for example OOMKilled) in the last 15 minutes."
  severity             = 2
  evaluation_frequency = "PT15M"
  window_duration      = "PT15M"
  tags                 = local.tags

  # The Container Insights tables only exist after the first data arrives,
  # which is after this rule is created.
  skip_query_validation = true

  criteria {
    query = <<-KQL
      KubePodInventory
      | where Namespace !in ("kube-system", "gatekeeper-system")
      | summarize Restarts = max(ContainerRestartCount) - min(ContainerRestartCount) by Namespace, Name
      | where Restarts > 0
    KQL

    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  dynamic "action" {
    for_each = length(local.alert_action_groups) > 0 ? [1] : []

    content {
      action_groups = local.alert_action_groups
    }
  }
}
