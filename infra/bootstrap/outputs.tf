output "state_storage_account" {
  description = "Storage account that holds the Terraform state."
  value       = azurerm_storage_account.state.name
}

output "github_variables" {
  description = "Run these once from the repo root to configure GitHub Actions."
  value       = <<-EOT
    gh variable set AZURE_TENANT_ID --body "${data.azurerm_client_config.current.tenant_id}"
    gh variable set AZURE_SUBSCRIPTION_ID --body "${data.azurerm_client_config.current.subscription_id}"
    gh variable set AZURE_CLIENT_ID_PLAN --body "${azurerm_user_assigned_identity.github["plan"].client_id}"
    gh variable set AZURE_CLIENT_ID_APPLY --body "${azurerm_user_assigned_identity.github["apply"].client_id}"
    gh variable set AZURE_CLIENT_ID_BUILD --body "${azurerm_user_assigned_identity.github["build"].client_id}"
  EOT
}
