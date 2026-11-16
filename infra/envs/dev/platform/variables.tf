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

variable "argocd_chart_version" {
  description = "Version of the argo-cd Helm chart (argoproj/argo-helm)."
  type        = string
  default     = "9.5.11"
}

variable "gitops_repo_url" {
  description = "Git repository Argo CD syncs from. Public, so Argo CD needs no credentials."
  type        = string
  default     = "https://github.com/kashastic/azure-agent-platform.git"
}

variable "gitops_revision" {
  description = "Branch, tag or commit Argo CD tracks."
  type        = string
  default     = "main"
}

variable "eurag_namespace" {
  description = "Namespace EURAG runs in (must match the federated credential in the AKS stack)."
  type        = string
  default     = "eurag"
}
