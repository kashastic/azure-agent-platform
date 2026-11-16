variable "name" {
  description = "Key Vault name (globally unique, 3 to 24 characters)."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the vault."
  type        = string
}

variable "tenant_id" {
  description = "Entra ID tenant that authenticates requests to the vault."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Workspace that receives the vault's audit log."
  type        = string
}

variable "secrets_officer_principal_ids" {
  description = "Principals that may create and update secrets, keyed by a stable label."
  type        = map(string)
  default     = {}
}

variable "soft_delete_retention_days" {
  description = "Days a deleted vault or secret can be recovered."
  type        = number
  default     = 7
}

variable "purge_protection_enabled" {
  description = "Blocks permanent deletion during the retention period. Off in dev so the lab can be rebuilt; on in production."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to the vault."
  type        = map(string)
}
