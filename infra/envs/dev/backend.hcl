# Written by infra/bootstrap. Every stack runs: terraform init -backend-config=../backend.hcl
resource_group_name  = "rg-agentplat-tfstate"
storage_account_name = "stagentplattfak7"
container_name       = "tfstate"
use_azuread_auth     = true
