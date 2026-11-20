output "vault_uri" {
  description = "Key Vault URI."
  value       = module.key_vault.uri
}

output "operator_secret_names" {
  description = "Secrets an operator must set by hand."
  value       = module.key_vault.operator_secret_names
}
