variable "name" {
  description = "Log Analytics workspace name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the workspace."
  type        = string
}

variable "retention_in_days" {
  description = "How long logs are kept. 30 days is the free retention period."
  type        = number
  default     = 30
}

variable "daily_quota_gb" {
  description = "Hard daily ingestion cap in GB. Stops a noisy workload from running up the bill."
  type        = number
  default     = 0.5
}

variable "tags" {
  description = "Tags applied to the workspace."
  type        = map(string)
}
