locals {
  name   = "${var.project}-${var.env}"
  unique = "${var.project}${var.env}${var.suffix}"

  required_tags = ["owner", "env", "cost-center"]

  tags = {
    project     = var.project
    env         = var.env
    owner       = var.owner
    cost-center = var.cost_center
    managed-by  = "terraform"
    stack       = "foundation"
  }

  # Platform admins fall back to whoever runs Terraform, so the first local
  # apply works without extra input. CI passes the list explicitly.
  platform_admins = length(var.platform_admin_object_ids) > 0 ? var.platform_admin_object_ids : [data.azurerm_client_config.current.object_id]
}
