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

variable "github_repository" {
  description = "GitHub repository (owner/name) whose workflows may sign in to Azure."
  type        = string
  default     = "kashastic/azure-agent-platform"
}

variable "github_oidc_subject_repository" {
  description = "How GitHub names the repository in OIDC token subjects. Newer repositories use immutable IDs: owner@owner_id/repo@repo_id."
  type        = string
  default     = "kashastic@44359944/azure-agent-platform@1459635005"
}
