# Vault settings (purge protection, soft delete) and variable validation.

mock_provider "azurerm" {
  mock_resource "azurerm_resource_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test-dev"
    }
  }
  mock_data "azurerm_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "00000000-0000-0000-0000-000000000001"
      client_id       = "00000000-0000-0000-0000-0000000000aa"
      object_id       = "00000000-0000-0000-0000-0000000000aa"
    }
  }
  mock_resource "azurerm_key_vault_secret" {
    defaults = {
      id = "https://kv-test-dev.vault.azure.net/secrets/mock/0000"
    }
  }
}
mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test-dev/providers/Microsoft.KeyVault/vaults/kv-test-dev"
      output = {
        properties = {
          vaultUri = "https://kv-test-dev.vault.azure.net/"
        }
      }
    }
  }
  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        results = [
          {
            id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/00000000-0000-0000-0000-0000000000e1"
            role_name = "Key Vault Secrets Officer"
          },
          {
            id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/00000000-0000-0000-0000-0000000000e2"
            role_name = "Key Vault Secrets User"
          },
        ]
      }
    }
  }
}
mock_provider "random" {}
mock_provider "time" {}
mock_provider "azuread" {
  mock_data "azuread_client_config" {
    defaults = {
      tenant_id = "00000000-0000-0000-0000-000000000001"
      object_id = "00000000-0000-0000-0000-0000000000aa"
    }
  }
  mock_data "azuread_service_principals" {
    defaults = {
      object_ids = []
    }
  }
}

variables {
  name                = "kv-test-dev"
  location            = "westeurope"
  resource_group_name = "rg-test-dev"
}

run "hardened_vault" {
  command = plan

  variables {
    purge_protection_enabled   = true
    soft_delete_retention_days = 90
    tags                       = { env = "prod" }
  }

  assert {
    condition     = azurerm_resource_group.this[0].tags["env"] == "prod" && azurerm_resource_group.this[0].location == "westeurope"
    error_message = "Tags and location should reach the resource group."
  }
  assert {
    condition     = module.key_vault.name == "kv-test-dev"
    error_message = "Vault name should be passed to the AVM module."
  }
}

run "invalid_name_too_short" {
  command = plan
  variables {
    name = "ab"
  }
  expect_failures = [var.name]
}

run "invalid_name_leading_digit" {
  command = plan
  variables {
    name = "1kv-test"
  }
  expect_failures = [var.name]
}

run "invalid_name_underscore" {
  command = plan
  variables {
    name = "kv_test_dev"
  }
  expect_failures = [var.name]
}

run "invalid_name_too_long" {
  command = plan
  variables {
    name = "kv-this-name-is-far-too-long"
  }
  expect_failures = [var.name]
}
