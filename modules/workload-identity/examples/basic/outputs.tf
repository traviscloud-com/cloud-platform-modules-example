output "client_id" {
  description = "Client ID to annotate the service account with."
  value       = module.workload_identity.client_id
}
