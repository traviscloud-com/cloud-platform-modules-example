output "client_id" {
  description = "Value for the repository's AZURE_CLIENT_ID variable."
  value       = module.github_actions_identity.client_id
}

output "federated_subjects" {
  description = "OIDC subjects the identity trusts."
  value       = module.github_actions_identity.federated_subjects
}
