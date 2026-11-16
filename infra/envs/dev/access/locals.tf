locals {
  name = "${var.project}-${var.env}"

  # platform/teams.yaml is the single source of truth for team access. The
  # same file feeds the Argo CD chart that creates each team's namespace.
  teams_file = yamldecode(file("${path.module}/../../../../platform/teams.yaml"))

  teams = {
    for team, spec in local.teams_file.teams : team => {
      description           = try(spec.description, "Team ${team}")
      members               = [for upn in try(spec.members, []) : tostring(upn)]
      keyvault_secrets_read = try(spec.keyvault_secrets_read, false)
    }
  }

  members = toset(flatten([for team in values(local.teams) : team.members]))
}
