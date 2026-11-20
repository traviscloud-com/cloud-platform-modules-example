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

run "dns_secrets_present" {
  command = plan

  variables {
    dns_secrets_present = true
    dns_azure_json      = "{\"cloud\":\"AzurePublicCloud\"}"
    dns_sp_secret       = "not-a-real-secret"
  }

  assert {
    condition     = toset(keys(local.dns_secrets)) == toset(["external_dns_azure_json", "cert_manager_azuredns_sp_secret"])
    error_message = "both DNS secret keys must appear when dns_secrets_present is true"
  }
  assert {
    condition = toset(module.vault.managed_secret_names) == toset([
      "external-dns-azure-json",
      "cert-manager-azuredns-client-secret",
      "oauth2-proxy-cookie-secret",
    ])
    error_message = "vault must manage the DNS secrets plus the generated cookie secret, and no ACR secrets"
  }
  assert {
    condition     = toset(module.vault.operator_secret_names) == toset(["google-oauth-client-id", "google-oauth-client-secret"])
    error_message = "operator placeholder secrets must be the Google OAuth pair by default"
  }
}

run "dns_secrets_absent_keeps_generated_only" {
  command = plan

  variables {
    dns_secrets_present = false
  }

  assert {
    condition     = toset(module.vault.managed_secret_names) == toset(["oauth2-proxy-cookie-secret"])
    error_message = "without DNS secrets only the generated cookie secret is managed"
  }
}

run "custom_operator_secrets" {
  command = plan

  variables {
    operator_managed_secret_names = ["slack-token"]
  }

  assert {
    condition     = toset(module.vault.operator_secret_names) == toset(["slack-token"])
    error_message = "operator_managed_secret_names must replace the default placeholders"
  }
}

run "outputs_with_mocked_identity" {
  command = apply

  assert {
    condition     = output.resource_group_name == "rg-demo-rancherlocal"
    error_message = "resource_group_name output must be the derived name"
  }
  assert {
    condition     = output.key_vault_uri == "https://kv-mock.vault.azure.net/" && endswith(output.key_vault_id, "/vaults/kv-mock")
    error_message = "vault outputs must pass through the vault module's outputs"
  }
  assert {
    condition     = output.tenant_id == "00000000-0000-0000-0000-000000000000"
    error_message = "tenant_id must come from the azuread client config"
  }
  assert {
    condition     = output.acr_login_server == null && output.acr_id == null && output.acr_pull_token_name == null
    error_message = "ACR outputs must be null when enable_acr is false"
  }
  assert {
    condition     = length(output.acr_push_client_ids) == 0
    error_message = "no push identities without ACR"
  }
}
