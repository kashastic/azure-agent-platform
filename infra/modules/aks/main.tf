# Control plane identity is created up front so it can be given exactly the
# network rights it needs on our subnet before the cluster exists.
resource "azurerm_user_assigned_identity" "control_plane" {
  name                = "id-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_role_assignment" "subnet_network_contributor" {
  scope                = var.subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
  principal_type       = "ServicePrincipal"
}

# Extra network resources the cluster may attach, such as a static public
# IP kept outside the node resource group.
resource "azurerm_role_assignment" "extra_network_contributor" {
  for_each = var.extra_network_contributor_scopes

  scope                = each.value
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
  principal_type       = "ServicePrincipal"
}

# Role assignments take a short while to propagate in Entra ID. Without this
# pause, cluster creation can fail with a "not authorized to join subnet" error.
resource "time_sleep" "rbac_propagation" {
  create_duration = "60s"

  depends_on = [
    azurerm_role_assignment.subnet_network_contributor,
    azurerm_role_assignment.extra_network_contributor,
  ]
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  node_resource_group = var.node_resource_group
  dns_prefix          = var.name
  kubernetes_version  = var.kubernetes_version
  sku_tier            = "Free"

  automatic_upgrade_channel = "patch"
  node_os_upgrade_channel   = "NodeImage"

  # Identity: people sign in with Entra ID, permissions are Azure RBAC role
  # assignments, and there is no shared admin kubeconfig to leak.
  local_account_disabled            = true
  role_based_access_control_enabled = true

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = var.tenant_id
  }

  # Workloads get Azure access through federated service account tokens.
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.control_plane.id]
  }

  default_node_pool {
    name                        = "system"
    vm_size                     = var.vm_size
    node_count                  = var.node_count
    max_pods                    = var.max_pods
    os_disk_size_gb             = var.os_disk_size_gb
    vnet_subnet_id              = var.subnet_id
    temporary_name_for_rotation = "systemtmp"
    tags                        = var.tags

    upgrade_settings {
      max_surge = "10%"
    }
  }

  # Azure CNI Overlay: nodes take IPs from our subnet, pods from a private
  # overlay range, so a small subnet still fits many pods. Cilium enforces
  # NetworkPolicies.
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
  }

  # Secrets Store CSI driver with the Azure Key Vault provider.
  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  # Container Insights, authenticated with the cluster's managed identity.
  oms_agent {
    log_analytics_workspace_id      = var.log_analytics_workspace_id
    msi_auth_for_monitoring_enabled = true
  }

  tags = var.tags

  lifecycle {
    # The patch upgrade channel moves the version forward on its own.
    ignore_changes = [
      kubernetes_version,
      default_node_pool[0].orchestrator_version,
    ]
  }

  depends_on = [time_sleep.rbac_propagation]
}

# Nodes pull images with the kubelet's managed identity: no registry secret.
resource "azurerm_role_assignment" "kubelet_acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "cluster_admin" {
  for_each = var.cluster_admin_principal_ids

  scope                = azurerm_kubernetes_cluster.this.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = each.value
}

# Container Insights data collection. The "logs and events" cost preset:
# container logs, Kubernetes events and pod inventory every 5 minutes,
# with kube-system excluded.
locals {
  container_insights_streams = [
    "Microsoft-ContainerLogV2",
    "Microsoft-KubeEvents",
    "Microsoft-KubePodInventory",
  ]
}

resource "azurerm_monitor_data_collection_rule" "container_insights" {
  name                = "dcr-${var.name}-insights"
  resource_group_name = var.resource_group_name
  location            = var.location
  description         = "Container Insights for ${var.name} (logs and events preset)."
  tags                = var.tags

  destinations {
    log_analytics {
      name                  = "workspace"
      workspace_resource_id = var.log_analytics_workspace_id
    }
  }

  data_flow {
    streams      = local.container_insights_streams
    destinations = ["workspace"]
  }

  data_sources {
    extension {
      name           = "ContainerInsightsExtension"
      extension_name = "ContainerInsights"
      streams        = local.container_insights_streams

      extension_json = jsonencode({
        dataCollectionSettings = {
          interval               = "5m"
          namespaceFilteringMode = "Exclude"
          namespaces             = ["kube-system", "gatekeeper-system"]
          enableContainerLogV2   = true
        }
      })
    }
  }
}

resource "azurerm_monitor_data_collection_rule_association" "container_insights" {
  name                    = "ContainerInsightsExtension"
  target_resource_id      = azurerm_kubernetes_cluster.this.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.container_insights.id
}

# Control plane audit: who changed what (kube-audit-admin skips read-only
# calls, which keeps volume low) and Entra ID sign-ins to the API server.
resource "azurerm_monitor_diagnostic_setting" "control_plane" {
  name                       = "diag-${var.name}"
  target_resource_id         = azurerm_kubernetes_cluster.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "kube-audit-admin"
  }

  enabled_log {
    category = "guard"
  }
}
