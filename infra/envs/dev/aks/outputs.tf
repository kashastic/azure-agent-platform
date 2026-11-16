output "cluster_name" {
  description = "AKS cluster name."
  value       = module.aks.name
}

output "resource_group_name" {
  description = "Resource group of the cluster."
  value       = azurerm_resource_group.aks.name
}

output "node_resource_group" {
  description = "Resource group AKS manages for nodes, disks and load balancers."
  value       = module.aks.node_resource_group
}

output "oidc_issuer_url" {
  description = "OIDC issuer for workload identity."
  value       = module.aks.oidc_issuer_url
}

output "get_credentials" {
  description = "Command to point kubectl at the cluster with Entra ID sign-in."
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.aks.name} --name ${module.aks.name} --overwrite-existing && kubelogin convert-kubeconfig -l azurecli"
}
