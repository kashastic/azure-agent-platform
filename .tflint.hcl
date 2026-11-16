config {
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# Every stack reads the same common.tfvars, so not every stack uses every
# shared variable. That is intended, not dead code.
rule "terraform_unused_declarations" {
  enabled = false
}
