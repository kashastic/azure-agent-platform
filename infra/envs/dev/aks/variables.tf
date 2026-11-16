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
  description = "Entra ID object IDs that get cluster admin. Empty means whoever runs Terraform."
  type        = list(string)
  default     = []
}

variable "alert_email" {
  description = "Where platform alerts go. Set it with TF_VAR_alert_email. Empty creates the alert rules without a notification."
  type        = string
  default     = ""
}

variable "node_vm_size" {
  description = "Node VM size. 2 vCPU and 8 GB fits Argo CD, Qdrant and EURAG's measured peak of about 2.4 GB."
  type        = string
  default     = "Standard_B2ms"
}

variable "node_count" {
  description = "Number of nodes."
  type        = number
  default     = 1
}

variable "kubernetes_version" {
  description = "Kubernetes version. null uses the AKS default; the patch channel keeps it current."
  type        = string
  default     = null
}

variable "eurag_namespace" {
  description = "Namespace EURAG runs in (must match the Argo CD application)."
  type        = string
  default     = "eurag"
}

variable "eurag_service_account" {
  description = "Service account EURAG runs as (must match the Helm chart)."
  type        = string
  default     = "eurag"
}
