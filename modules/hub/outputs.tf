# These outputs are the cross-stack contract consumed by aks-spoke (and by
# the dev/eastus2 hub for the hub<->hub peering) via a terragrunt dependency
# block. Keep them in sync with the `hub` mock_outputs in
# units/aks-spoke/terragrunt.hcl and units/hub/terragrunt.hcl (remote_hub) of
# cloud-platform-catalog-example.

output "dns_resolver_inbound_ip" {
  description = "Private IP of the DNS Private Resolver inbound endpoint (the DNS server to point on-prem forwarders at), or null when disabled."
  value       = var.enable_dns_resolver ? module.dns_resolver[0].inbound_endpoint_ips["hub"] : null
}

output "firewall_private_ip" {
  description = "Private IP of the hub firewall, or null when the firewall is disabled."
  value       = module.hub.virtual_networks["hub"].hub_router_ip_address
}

output "location" {
  description = "Azure region of the hub."
  value       = var.location
}

output "resource_group_name" {
  description = "Name of the hub resource group."
  value       = azurerm_resource_group.hub.name
}

output "vnet_id" {
  description = "Resource ID of the hub virtual network."
  value       = module.hub.virtual_networks["hub"].id
}

output "vnet_name" {
  description = "Name of the hub virtual network."
  value       = module.hub.virtual_networks["hub"].name
}
