# Platform: bootstraps GitOps. Terraform installs Argo CD and registers the
# applications once; from then on Argo CD deploys whatever is in Git.

data "azurerm_client_config" "current" {}

data "azurerm_kubernetes_cluster" "this" {
  name                = "aks-${local.name}"
  resource_group_name = "rg-${local.name}-aks"
}

data "azurerm_container_registry" "core" {
  name                = "acr${local.unique}"
  resource_group_name = "rg-${local.name}-core"
}

data "azurerm_key_vault" "core" {
  name                = "kv-${local.name}-${var.suffix}"
  resource_group_name = "rg-${local.name}-core"
}

data "azurerm_user_assigned_identity" "eurag" {
  name                = "id-${local.name}-eurag"
  resource_group_name = "rg-${local.name}-core"
}

data "azurerm_public_ip" "ingress" {
  name                = "pip-${local.name}-ingress"
  resource_group_name = "rg-${local.name}-core"
}

data "azurerm_storage_account" "data" {
  name                = "st${local.unique}"
  resource_group_name = "rg-${local.name}-core"
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = "argocd"
  create_namespace = true
  timeout          = 900
  wait             = true

  values = [file("${path.module}/values/argocd.yaml")]
}

# The Applications come from a small local chart, so the CRDs installed by
# Argo CD above don't have to exist when Terraform plans.
#
# Terraform owns the values that come from Azure (identity, Key Vault,
# registry) and hands them to Argo CD as Helm parameters. Git owns
# everything else, including the image tag the build pipeline commits.
resource "helm_release" "platform_apps" {
  name      = "platform-apps"
  chart     = "${path.module}/../../../charts/argocd-apps"
  namespace = "argocd"

  values = [yamlencode({
    repoURL        = var.gitops_repo_url
    targetRevision = var.gitops_revision
    labels         = local.labels

    edge = {
      enabled               = var.public_hostname != ""
      hostname              = var.public_hostname
      staticIpName          = data.azurerm_public_ip.ingress.name
      staticIpResourceGroup = data.azurerm_public_ip.ingress.resource_group_name
    }

    eurag = {
      namespace          = var.eurag_namespace
      imageRepository    = "${data.azurerm_container_registry.core.login_server}/eurag"
      webImageRepository = "${data.azurerm_container_registry.core.login_server}/eurag-web"
      keyVaultName       = data.azurerm_key_vault.core.name
      tenantId           = data.azurerm_client_config.current.tenant_id
      workloadClientId   = data.azurerm_user_assigned_identity.eurag.client_id
      publicHostname     = var.public_hostname
      corpusBlobUrl      = "${data.azurerm_storage_account.data.primary_blob_endpoint}corpus/eurag-raw.tgz"
    }
  })]

  depends_on = [helm_release.argocd]
}
