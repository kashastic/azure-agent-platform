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
