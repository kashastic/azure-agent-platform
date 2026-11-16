# Subscription from ARM_SUBSCRIPTION_ID; resource providers are registered once by hand (see the runbook).
provider "azurerm" {
  features {}

  resource_provider_registrations = "none"
}

# Helm talks to the cluster with an Entra ID token from kubelogin, reusing
# the Azure CLI sign-in. The cluster has no local admin account to fall back on.
provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.this.kube_config[0].host
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "kubelogin"
      # 6dae42f8-... is the fixed application ID of the AKS Entra ID server.
      args = ["get-token", "--login", "azurecli", "--server-id", "6dae42f8-4368-4678-94ff-3960e28e3630"]
    }
  }
}
