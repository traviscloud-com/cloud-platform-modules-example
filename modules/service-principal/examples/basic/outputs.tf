output "client_id" {
  value = module.service_principal.client_id
}

output "object_id" {
  value = module.service_principal.object_id
}

output "secret_end_date" {
  value = module.service_principal.secret_end_date
}

output "client_secret" {
  value     = module.service_principal.client_secret
  sensitive = true
}
