locals {
  name   = "${var.project}-${var.env}"
  unique = "${var.project}${var.env}${var.suffix}"

  # Labels Argo CD puts on the namespaces it creates, mirroring the Azure tags.
  labels = {
    env         = var.env
    owner       = var.owner
    cost-center = var.cost_center
  }
}
