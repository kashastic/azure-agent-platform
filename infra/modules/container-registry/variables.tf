variable "name" {
  description = "Registry name (globally unique, alphanumeric only)."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the registry."
  type        = string
}

variable "sku" {
  description = "Registry tier. Basic is enough for a lab; Premium adds private endpoints and geo-replication."
  type        = string
  default     = "Basic"
}

variable "push_principal_ids" {
  description = "Service principals or managed identities allowed to push images, keyed by a stable label."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags applied to the registry."
  type        = map(string)
}
