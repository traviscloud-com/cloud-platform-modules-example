# Offline tests for modules/key-vault: every provider is mocked, nothing talks to Azure.

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
      object_ids = ["00000000-0000-0000-0000-0000000000b1"]
    }
  }
}

variables {
  name                = "kv-test-dev"
  location            = "westeurope"
  resource_group_name = "rg-test-dev"
}

run "defaults" {
  command = plan

  assert {
    condition     = length(azurerm_resource_group.this) == 1 && azurerm_resource_group.this[0].name == "rg-test-dev"
    error_message = "Resource group should be created by default."
  }
  assert {
    condition     = length(random_password.generated) == 0 && length(azurerm_key_vault_secret.operator_managed) == 0
    error_message = "No secrets expected by default."
  }
  assert {
    condition     = output.resource_group_name == "rg-test-dev"
    error_message = "resource_group_name output should echo the input."
  }
  assert {
    condition     = output.tenant_id == "00000000-0000-0000-0000-000000000001"
    error_message = "tenant_id output should come from the azuread client config."
  }
  assert {
    condition     = length(output.managed_secret_names) == 0 && length(output.operator_secret_names) == 0
    error_message = "Secret name outputs should be empty by default."
  }
  assert {
    condition     = length(data.azuread_service_principals.officers) == 1 && length(data.azuread_service_principals.readers) == 1
    error_message = "Default officer and reader SP lookups should be performed."
  }
  # Officers: current principal plus the one SP resolved by the (mocked) lookup.
  assert {
    condition     = length(local.officer_ids) == 2 && contains(local.officer_ids, "00000000-0000-0000-0000-0000000000aa")
    error_message = "Officers should be the applying principal plus the resolved SPs."
  }
  assert {
    condition     = length(local.role_assignments) == 3
    error_message = "Expected 2 officer + 1 reader role assignments."
  }
  assert {
    condition     = alltrue([for k, v in local.role_assignments : v.role_definition_id_or_name == (startswith(k, "officer-") ? "Key Vault Secrets Officer" : "Key Vault Secrets User")])
    error_message = "Officer keys map to Secrets Officer, reader keys to Secrets User."
  }
}

run "existing_resource_group" {
  command = plan

  variables {
    create_resource_group = false
  }

  assert {
    condition     = length(azurerm_resource_group.this) == 0
    error_message = "No resource group should be created."
  }
  assert {
    condition     = startswith(local.resource_group_id, "/subscriptions/") && endswith(local.resource_group_id, "/resourceGroups/rg-test-dev")
    error_message = "resource_group_id should be built from the subscription and the given name."
  }
  assert {
    condition     = output.resource_group_name == "rg-test-dev"
    error_message = "resource_group_name output should echo the input."
  }
}

run "no_service_principal_lookups" {
  command = plan

  variables {
    officer_service_principal_names = []
    reader_service_principal_names  = []
  }

  assert {
    condition     = length(data.azuread_service_principals.officers) == 0 && length(data.azuread_service_principals.readers) == 0
    error_message = "No lookups when name lists are empty."
  }
  assert {
    condition     = length(local.role_assignments) == 1 && contains(keys(local.role_assignments), "officer-00000000-0000-0000-0000-0000000000aa")
    error_message = "Only the applying principal should remain as officer."
  }
}

run "role_assignments" {
  command = plan

  variables {
    officer_service_principal_names  = []
    reader_service_principal_names   = []
    additional_officer_principal_ids = ["00000000-0000-0000-0000-0000000000c1"]
    secrets_user_principals = {
      aks = {
        principal_id = "00000000-0000-0000-0000-0000000000d1"
        description  = "AKS ESO identity"
      }
      human = {
        principal_id   = "00000000-0000-0000-0000-0000000000d2"
        principal_type = "User"
      }
    }
  }

  assert {
    condition     = length(local.officer_ids) == 2 && contains(local.officer_ids, "00000000-0000-0000-0000-0000000000c1")
    error_message = "Additional officer IDs should be included."
  }
  assert {
    condition     = local.role_assignments["aks"].principal_type == "ServicePrincipal" && local.role_assignments["human"].principal_type == "User"
    error_message = "principal_type defaults to ServicePrincipal and can be overridden."
  }
  assert {
    condition     = local.role_assignments["aks"].role_definition_id_or_name == "Key Vault Secrets User" && local.role_assignments["aks"].description == "AKS ESO identity"
    error_message = "Consumers get Secrets User with their description."
  }
  assert {
    condition     = length(local.role_assignments) == 4
    error_message = "Expected 2 officers + 2 consumers."
  }
}
