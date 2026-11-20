terraform {
  required_version = ">= 1.11, < 2.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = ">= 2.9, < 3.0"
    }
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

provider "azapi" {}

# One stamp with a static /22, peered to an existing hub, every optional
# identity and add-on off. The hub IDs are placeholders.
module "aks_spoke" {
  source = "../.."

  environment  = "dev"
  region_short = "wus3"
  location     = "westus3"
  name_prefix  = "example"

  spoke_address_space = ["10.16.0.0/22"]
  hub_vnet_id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub-dev-wus3/providers/Microsoft.Network/virtualNetworks/vnet-hub-dev-wus3"
  hub_vnet_name       = "vnet-hub-dev-wus3"

  tags = { environment = "dev" }
}
