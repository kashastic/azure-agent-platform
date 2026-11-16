variable "name" {
  description = "Cluster name, also used as the DNS prefix."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the cluster and its identity."
  type        = string
}

variable "node_resource_group" {
  description = "Name of the resource group AKS creates for nodes, disks and load balancers."
  type        = string
}

variable "tenant_id" {
  description = "Entra ID tenant used for cluster sign-in."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version. null uses the current AKS default."
  type        = string
  default     = null
}

variable "vm_size" {
  description = "Node VM size."
  type        = string
}

variable "node_count" {
  description = "Number of nodes in the system pool."
  type        = number
  default     = 1
}

variable "max_pods" {
  description = "Maximum pods per node. AKS reserves memory per possible pod, so a lower number leaves more memory for workloads."
  type        = number
  default     = 50
}

variable "os_disk_size_gb" {
  description = "OS disk size per node."
  type        = number
  default     = 64
}

variable "subnet_id" {
  description = "Subnet for the nodes."
  type        = string
}

variable "extra_network_contributor_scopes" {
  description = "Other network resources the cluster's identity may use, keyed by a static name (for example a static public IP for the gateway)."
  type        = map(string)
  default     = {}
}

variable "pod_cidr" {
  description = "Overlay range for pod IPs. Must not overlap the virtual network."
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "Range for Kubernetes service IPs. Must not overlap the virtual network or pod range."
  type        = string
  default     = "10.20.0.0/16"
}

variable "dns_service_ip" {
  description = "IP of the cluster DNS service, inside service_cidr."
  type        = string
  default     = "10.20.0.10"
}

variable "acr_id" {
  description = "Container registry the nodes pull images from."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Workspace for Container Insights and control plane logs."
  type        = string
}

variable "cluster_admin_principal_ids" {
  description = "Principals that get cluster admin through Azure RBAC, keyed by a stable label."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags applied to every taggable resource."
  type        = map(string)
}
