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

# Cheapest hub: VNet only, no firewall, resolver or bastion.
module "hub" {
  source = "../.."

  environment   = "dev"
  region_short  = "wus3"
  location      = "westus3"
  address_space = ["10.0.0.0/22"]

  tags = { environment = "dev" }
}
