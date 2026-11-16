variable "name_prefix" {
  description = "Prefix for the policy assignment names."
  type        = string
}

variable "resource_group_id" {
  description = "Resource group the policies are assigned to."
  type        = string
}

variable "allowed_locations" {
  description = "Regions resources may be created in."
  type        = list(string)
}

variable "required_tags" {
  description = "Tag names every taggable resource must carry."
  type        = list(string)
}
