# Shared by every stack through infra/envs/dev/common.tfvars.
variable "project" {
  description = "Short project name used in every resource name."
  type        = string
}

variable "env" {
  description = "Environment name, for example dev."
  type        = string
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
}

variable "suffix" {
  description = "Short suffix that keeps globally unique names (Key Vault, registry, storage) unique."
  type        = string
}

variable "owner" {
  description = "Value of the owner tag."
  type        = string
}

variable "cost_center" {
  description = "Value of the cost-center tag."
  type        = string
}

variable "platform_admin_object_ids" {
  description = "Entra ID object IDs of platform admins (Key Vault secrets officers). Empty means whoever runs Terraform."
  type        = list(string)
  default     = []
}

variable "alert_email" {
  description = "Where budget alerts go. Set it with TF_VAR_alert_email so no address is committed. Empty skips the budget."
  type        = string
  default     = ""
}

variable "monthly_budget" {
  description = "Monthly budget for the whole subscription, in the billing currency."
  type        = number
  default     = 20
}

variable "budget_start_date" {
  description = "First day of the first budget month (RFC 3339). Cannot change after creation."
  type        = string
  default     = "2026-11-01T00:00:00Z"
}
