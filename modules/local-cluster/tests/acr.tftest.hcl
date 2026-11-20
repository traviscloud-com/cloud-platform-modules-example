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
  enable_acr  = true
  acr_push_repositories = {
    app = {
      repository = "example-org/app"
    }
    tools = {
      repository = "example-org/tools"
      subjects   = ["ref:refs/heads/main", "ref:refs/tags/v1"]
    }
  }
}

run "acr_with_push_identities_and_pull_token" {
  command = plan

  assert {
    condition     = azurerm_container_registry.this[0].name == "crdemorancherlocal"
    error_message = "registry name must be cr<prefix><env>"
  }
  assert {
    condition     = azurerm_container_registry.this[0].sku == "Basic" && azurerm_container_registry.this[0].admin_enabled == false && azurerm_container_registry.this[0].anonymous_pull_enabled == false
    error_message = "registry must be Basic with admin and anonymous pull disabled"
  }
  assert {
    condition     = toset(keys(module.push_identity)) == toset(["app", "tools"])
    error_message = "one push identity per acr_push_repositories key"
  }
  assert {
    condition     = length(azurerm_container_registry_scope_map.pull) == 1 && length(azurerm_container_registry_token.pull) == 1
    error_message = "pull scope map and token must be created"
  }
  assert {
    condition     = azurerm_container_registry_scope_map.pull[0].name == "pull-rancherlocal" && azurerm_container_registry_token.pull[0].name == "acr-pull-rancherlocal"
    error_message = "scope map and token names derive from the environment"
  }
  assert {
    condition = toset(azurerm_container_registry_scope_map.pull[0].actions) == toset([
      "repositories/app/content/read",
      "repositories/app/metadata/read",
      "repositories/tools/content/read",
      "repositories/tools/metadata/read",
    ])
    error_message = "pull token must be read-only on the push repositories by default"
  }
  assert {
    condition     = toset(keys(local.acr_secrets)) == toset(["acr_login_server", "acr_pull_username", "acr_pull_password"])
    error_message = "the three imagePullSecret vault secrets must be declared"
  }
  assert {
    condition = toset(module.vault.managed_secret_names) == toset([
      "oauth2-proxy-cookie-secret",
      "acr-login-server",
      "acr-pull-username",
      "acr-pull-password",
    ])
    error_message = "vault must manage the ACR pull secrets"
  }
}

run "acr_outputs" {
  command = apply

  assert {
    condition     = output.acr_login_server == "mockacr.azurecr.io"
    error_message = "login server must be exposed"
  }
  assert {
    condition     = output.acr_pull_token_name == "acr-pull-rancherlocal"
    error_message = "pull token name must be exposed"
  }
  assert {
    condition     = output.acr_pull_password_end_date == "2030-01-01T00:00:00Z"
    error_message = "pull password expiry must come from time_rotating"
  }
  assert {
    condition     = toset(keys(output.acr_push_client_ids)) == toset(["app", "tools"]) && toset(keys(output.acr_push_subjects)) == toset(["app", "tools"])
    error_message = "push outputs are keyed by repository key"
  }
  assert {
    condition     = contains(output.acr_push_subjects["tools"], "repo:example-org/tools:ref:refs/tags/v1")
    error_message = "federated subjects must be <prefix>:<subject>"
  }
}

run "pull_repositories_override" {
  command = plan

  variables {
    acr_pull_repositories = ["only-this"]
    acr_name              = "MyRegistry01"
    acr_sku               = "Standard"
  }

  assert {
    condition     = toset(azurerm_container_registry_scope_map.pull[0].actions) == toset(["repositories/only-this/content/read", "repositories/only-this/metadata/read"])
    error_message = "explicit acr_pull_repositories must win over push keys"
  }
  assert {
    condition     = azurerm_container_registry.this[0].name == "MyRegistry01" && azurerm_container_registry.this[0].sku == "Standard"
    error_message = "acr_name and acr_sku overrides must apply"
  }
}

run "acr_without_repositories_has_no_pull_token" {
  command = plan

  variables {
    acr_push_repositories = {}
  }

  assert {
    condition     = length(azurerm_container_registry.this) == 1 && length(azurerm_container_registry_token.pull) == 0 && length(local.acr_secrets) == 0
    error_message = "registry alone must not create a token or vault secrets"
  }
}

run "acr_disabled_ignores_push_repositories" {
  command = plan

  variables {
    enable_acr = false
  }

  assert {
    condition     = length(module.push_identity) == 0 && length(azurerm_container_registry.this) == 0
    error_message = "enable_acr = false must suppress ACR and identities"
  }
}

run "invalid_acr_name" {
  command = plan
  variables {
    acr_name = "bad-name"
  }
  expect_failures = [var.acr_name]
}

run "invalid_acr_sku" {
  command = plan
  variables {
    acr_sku = "Free"
  }
  expect_failures = [var.acr_sku]
}

run "invalid_push_repository_key" {
  command = plan
  variables {
    acr_push_repositories = { "Bad_Key" = { repository = "o/r" } }
  }
  expect_failures = [var.acr_push_repositories]
}
