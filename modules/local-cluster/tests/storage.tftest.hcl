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
  mock_resource "azurerm_storage_account" {
    defaults = {
      id                    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Storage/storageAccounts/mockst"
      primary_blob_endpoint = "https://mockst.blob.core.windows.net/"
    }
  }
  mock_resource "azurerm_storage_container" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Storage/storageAccounts/mockst/blobServices/default/containers/mock"
    }
  }
  mock_resource "azurerm_storage_management_policy" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Storage/storageAccounts/mockst/managementPolicies/default"
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
  environment        = "rancherlocal"
  location           = "westeurope"
  enable_storage     = true
  storage_containers = ["argo-workflows", "backups"]
}

run "storage_account_containers_and_principal" {
  command = plan

  assert {
    condition     = azurerm_storage_account.this[0].name == "stdemorancherlocal"
    error_message = "storage account name must be st<prefix><env>"
  }
  assert {
    condition     = azurerm_storage_account.this[0].account_tier == "Standard" && azurerm_storage_account.this[0].account_replication_type == "LRS"
    error_message = "storage account must be Standard LRS"
  }
  assert {
    condition     = azurerm_storage_account.this[0].shared_access_key_enabled == false && azurerm_storage_account.this[0].allow_nested_items_to_be_public == false && azurerm_storage_account.this[0].min_tls_version == "TLS1_2"
    error_message = "storage account must have shared keys and public blobs off, TLS 1.2 minimum"
  }
  assert {
    condition     = toset(keys(azurerm_storage_container.this)) == toset(["argo-workflows", "backups"])
    error_message = "one container per storage_containers entry"
  }
  assert {
    condition     = alltrue([for c in azurerm_storage_container.this : c.container_access_type == "private"])
    error_message = "containers must be private"
  }
  assert {
    condition     = length(module.storage_principal) == 1 && toset(keys(azurerm_role_assignment.storage)) == toset(["argo-workflows", "backups"])
    error_message = "one principal with one role assignment per container"
  }
  assert {
    condition     = alltrue([for r in azurerm_role_assignment.storage : r.role_definition_name == "Storage Blob Data Contributor" && r.principal_type == "ServicePrincipal"])
    error_message = "the principal must be Storage Blob Data Contributor on the containers"
  }
  assert {
    condition     = length(azurerm_storage_management_policy.retention) == 1 && azurerm_storage_management_policy.retention[0].rule[0].actions[0].base_blob[0].delete_after_days_since_modification_greater_than == 90
    error_message = "blobs must be deleted after 90 days by default"
  }
  assert {
    condition = toset(module.vault.managed_secret_names) == toset([
      "oauth2-proxy-cookie-secret",
      "storage-blob-endpoint",
      "storage-sp-tenant-id",
      "storage-sp-client-id",
      "storage-sp-client-secret",
    ])
    error_message = "vault must manage the storage client secrets"
  }
}

run "storage_outputs" {
  command = apply

  assert {
    condition     = output.storage_account_name == "stdemorancherlocal" && output.storage_blob_endpoint == "https://mockst.blob.core.windows.net/"
    error_message = "account name and blob endpoint must be exposed"
  }
  assert {
    condition     = output.storage_container_names == tolist(["argo-workflows", "backups"])
    error_message = "container names must be exposed, sorted"
  }
  assert {
    condition     = output.storage_client_id == "00000000-0000-0000-0000-000000000000" && output.storage_secret_end_date != null
    error_message = "the storage principal's client id and secret expiry must be exposed"
  }
}

run "role_assignments_are_scoped_to_the_containers" {
  command = apply

  assert {
    condition     = alltrue([for k, r in azurerm_role_assignment.storage : r.scope == azurerm_storage_container.this[k].id])
    error_message = "each role assignment must be scoped to its container, not the account"
  }
}

run "storage_overrides" {
  command = plan

  variables {
    storage_account_name   = "stcustom01"
    storage_retention_days = 0
  }

  assert {
    condition     = azurerm_storage_account.this[0].name == "stcustom01"
    error_message = "storage_account_name override must apply"
  }
  assert {
    condition     = length(azurerm_storage_management_policy.retention) == 0
    error_message = "storage_retention_days = 0 must not create a lifecycle policy"
  }
}

run "storage_without_containers_has_no_principal" {
  command = plan

  variables {
    storage_containers = []
  }

  assert {
    condition     = length(azurerm_storage_account.this) == 1 && length(module.storage_principal) == 0 && length(azurerm_role_assignment.storage) == 0 && length(local.storage_secrets) == 0
    error_message = "an account alone must not create a principal, role assignments or vault secrets"
  }
}

run "storage_disabled_ignores_containers" {
  command = plan

  variables {
    enable_storage = false
  }

  assert {
    condition     = length(azurerm_storage_account.this) == 0 && length(azurerm_storage_container.this) == 0 && length(module.storage_principal) == 0 && length(local.storage_secrets) == 0
    error_message = "enable_storage = false must suppress the account, containers and principal"
  }
  assert {
    condition     = output.storage_account_name == null && length(output.storage_container_names) == 0
    error_message = "storage outputs must be empty when disabled"
  }
}

run "invalid_storage_account_name" {
  command = plan
  variables {
    storage_account_name = "Bad-Name"
  }
  expect_failures = [var.storage_account_name]
}

run "invalid_container_name" {
  command = plan
  variables {
    storage_containers = ["Bad_Container"]
  }
  expect_failures = [var.storage_containers]
}

run "invalid_retention" {
  command = plan
  variables {
    storage_retention_days = -1
  }
  expect_failures = [var.storage_retention_days]
}
