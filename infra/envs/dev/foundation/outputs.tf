output "resource_group_name" {
  description = "Core resource group."
  value       = azurerm_resource_group.core.name
}

output "key_vault_name" {
  description = "Key Vault for platform and workload secrets."
  value       = module.key_vault.name
}

output "acr_name" {
  description = "Container registry name (GitHub variable ACR_NAME)."
  value       = module.container_registry.name
}

output "acr_login_server" {
  description = "Container registry login server."
  value       = module.container_registry.login_server
}

output "eurag_identity_client_id" {
  description = "Client ID of EURAG's workload identity."
  value       = azurerm_user_assigned_identity.eurag.client_id
}

output "aks_subnet_id" {
  description = "Subnet for AKS nodes."
  value       = module.network.subnet_ids["snet-aks"]
}

output "log_analytics_workspace_id" {
  description = "Workspace for logs and metrics."
  value       = module.log_analytics.id
}

output "ingress_ip_name" {
  description = "Name of the gateway's static public IP."
  value       = azurerm_public_ip.ingress.name
}

output "ingress_ip_address" {
  description = "The gateway's public address. Point the DNS record here."
  value       = azurerm_public_ip.ingress.ip_address
}

output "data_storage_account_name" {
  description = "Storage account holding the EURAG corpus cache."
  value       = azurerm_storage_account.data.name
}
