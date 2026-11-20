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

  subscription_id = "00000000-0000-0000-0000-000000000000"
}

module "github_actions_identity" {
  source = "../.."

  name                = "id-gh-example-dev"
  location            = "westeurope"
  resource_group_name = "rg-example-dev"
  repository          = "example-org/example-repo"
  subjects            = ["ref:refs/heads/main", "environment:dev"]

  role_assignments = {
    acr_push = {
      scope                = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-example-dev/providers/Microsoft.ContainerRegistry/registries/acrexample"
      role_definition_name = "AcrPush"
      description          = "Push images from CI"
    }
  }

  tags = {
    environment = "dev"
  }
}
