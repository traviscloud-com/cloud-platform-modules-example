mock_provider "azurerm" {
  mock_resource "azurerm_resource_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg"
    }
  }
  mock_resource "azurerm_container_registry" {
    defaults = {
      id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.ContainerRegistry/registries/mockacr"
      login_server = "mockacr.azurecr.io"
    }
  }
  mock_resource "azurerm_container_registry_scope_map" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.ContainerRegistry/registries/mockacr/scopeMaps/pull"
    }
  }
  mock_resource "azurerm_container_registry_token" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.ContainerRegistry/registries/mockacr/tokens/pull"
    }
  }
  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mock-id"
      client_id    = "00000000-0000-0000-0000-000000000000"
      principal_id = "00000000-0000-0000-0000-000000000000"
      tenant_id    = "00000000-0000-0000-0000-000000000000"
    }
  }
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id       = "00000000-0000-0000-0000-000000000000"
      subscription_id = "00000000-0000-0000-0000-000000000000"
      object_id       = "00000000-0000-0000-0000-000000000000"
      client_id       = "00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "azuread" {
  mock_data "azuread_client_config" {
    defaults = {
      tenant_id = "00000000-0000-0000-0000-000000000000"
      object_id = "00000000-0000-0000-0000-000000000000"
      client_id = "00000000-0000-0000-0000-000000000000"
    }
  }
  mock_data "azuread_service_principals" {
    defaults = {
      object_ids = ["00000000-0000-0000-0000-000000000000"]
    }
  }
  mock_resource "azuread_service_principal" {
    defaults = {
      object_id = "00000000-0000-0000-0000-000000000000"
      client_id = "00000000-0000-0000-0000-000000000000"
    }
  }
  mock_resource "azuread_application" {
    defaults = {
      id        = "/applications/00000000-0000-0000-0000-000000000000"
      object_id = "00000000-0000-0000-0000-000000000000"
      client_id = "00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "random" {}

mock_provider "time" {
  mock_resource "time_rotating" {
    defaults = {
      rotation_rfc3339 = "2030-01-01T00:00:00Z"
    }
  }
  mock_resource "time_static" {
    defaults = {
      rfc3339 = "2030-01-01T00:00:00Z"
    }
  }
}

# The AVM key vault module talks to ARM through azapi, whose source (Azure/azapi)
# is not in local-cluster's own required_providers, so it cannot be mocked from
# a test file here. Replace the AVM module itself; the key-vault wrapper, the
# secrets maps and everything in local-cluster still run for real.
override_module {
  target = module.vault.module.key_vault
  outputs = {
    name        = "kv-mock"
    uri         = "https://kv-mock.vault.azure.net/"
    resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.KeyVault/vaults/kv-mock"
  }
}

variables {
  environment = "rancherlocal"
  location    = "westeurope"
}

run "defaults" {
  command = plan

  assert {
    condition     = azurerm_resource_group.this.name == "rg-demo-rancherlocal"
    error_message = "resource group name must be rg-<prefix>-<env>"
  }
  assert {
    condition     = local.key_vault_name == "kv-demo-rancherlocal"
    error_message = "key vault name must be kv-<prefix>-<env>"
  }
  assert {
    condition     = length(azurerm_container_registry.this) == 0 && length(module.push_identity) == 0
    error_message = "ACR and push identities must be off by default"
  }
  assert {
    condition     = length(local.dns_secrets) == 0 && length(local.acr_secrets) == 0
    error_message = "no DNS or ACR secrets by default"
  }
  assert {
    condition     = length(data.azuread_service_principals.owners) == 1
    error_message = "default owner names trigger the principal lookup"
  }
}

run "overrides_and_empty_owners" {
  command = plan

  variables {
    name_prefix                   = "acme"
    resource_group_name           = "rg-custom"
    key_vault_name                = "kv-custom-1"
    owner_service_principal_names = []
  }

  assert {
    condition     = azurerm_resource_group.this.name == "rg-custom" && local.key_vault_name == "kv-custom-1"
    error_message = "name overrides must win over derived names"
  }
  assert {
    condition     = length(data.azuread_service_principals.owners) == 0
    error_message = "no owner lookup when owner list is empty"
  }
}

run "environment_too_long" {
  command = plan
  variables {
    environment = "waytoolongenvironment"
  }
  expect_failures = [var.environment]
}

run "environment_uppercase" {
  command = plan
  variables {
    environment = "Dev"
  }
  expect_failures = [var.environment]
}
