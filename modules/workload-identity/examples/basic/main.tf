terraform {
  required_version = ">= 1.11, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.46, < 5.0"
    }
  }
}

provider "azurerm" {
  features {}
  # Placeholder; use your own subscription.
  subscription_id = "00000000-0000-0000-0000-000000000000"
}

# Identity for one Kubernetes service account, with one role. The issuer URL,
# resource group and scope are placeholders.
module "workload_identity" {
  source = "../.."

  name                = "id-external-dns-example-dev-wus3"
  location            = "westus3"
  resource_group_name = "rg-aks-dev-wus3"
  oidc_issuer_url     = "https://westus3.oic.prod-aks.azure.com/00000000-0000-0000-0000-000000000000/00000000-0000-0000-0000-000000000000/"
  service_account     = "external-dns/external-dns"

  role_assignments = {
    zone = {
      scope                = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns-public/providers/Microsoft.Network/dnsZones/dev.azure.example.com"
      role_definition_name = "DNS Zone Contributor"
    }
  }
}
