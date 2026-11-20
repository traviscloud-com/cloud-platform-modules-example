terraform {
  required_version = ">= 1.11, < 2.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = ">= 2.12, < 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.0, < 4.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.81, < 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5, < 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  # Placeholder; use your own subscription.
  subscription_id = "00000000-0000-0000-0000-000000000000"
}

provider "azapi" {}

provider "azuread" {}

provider "random" {}

module "key_vault" {
  source = "../.."

  name                = "kv-example-dev"
  location            = "westeurope"
  resource_group_name = "rg-example-dev"

  # No pipeline identities in the example (the defaults name real ones;
  # unresolved names are ignored anyway).
  officer_service_principal_names = []
  reader_service_principal_names  = []

  generated_secrets             = { cookie = "oauth2-proxy-cookie-secret" }
  operator_managed_secret_names = ["slack-webhook-url"]

  tags = { environment = "dev" }
}
