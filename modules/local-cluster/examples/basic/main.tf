terraform {
  required_version = ">= 1.11, < 2.0"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.0, < 4.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.81, < 5.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.12, < 1.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "00000000-0000-0000-0000-000000000000"
}

provider "azuread" {
  tenant_id = "00000000-0000-0000-0000-000000000000"
}

module "local_cluster" {
  source = "../.."

  environment = "example"
  location    = "westeurope"
  name_prefix = "demo"

  # Registry with one push identity (enable_acr = true) is shown in the README.
  tags = { managed_by = "terraform", example = "basic" }
}
