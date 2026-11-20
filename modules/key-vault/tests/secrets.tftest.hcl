# Secret handling: managed, generated and operator-placeholder secrets.

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

run "managed_secrets" {
  command = plan

  variables {
    managed_secrets = {
      db = { name = "db-password" }
      api = {
        name         = "api-key"
        content_type = "application/json"
        tags         = { team = "platform" }
      }
    }
    managed_secret_values = {
      db  = "hunter2"
      api = "{}"
    }
  }

  assert {
    condition     = local.secrets["db"].content_type == "text/plain" && local.secrets["api"].content_type == "application/json"
    error_message = "content_type defaults to text/plain."
  }
  assert {
    condition     = toset(output.managed_secret_names) == toset(["db-password", "api-key"])
    error_message = "managed_secret_names should list managed secret names."
  }
  assert {
    condition     = length(random_password.generated) == 0
    error_message = "No passwords should be generated."
  }
}

run "generated_secrets" {
  command = apply

  variables {
    generated_secrets = {
      cookie = "oauth2-proxy-cookie-secret"
      other  = "other-secret"
    }
  }

  assert {
    condition     = length(random_password.generated) == 2 && alltrue([for p in random_password.generated : p.length == 32 && p.special == false])
    error_message = "Each generated secret gets a 32-char alphanumeric password."
  }
  assert {
    condition     = local.generated_secrets["cookie"].name == "oauth2-proxy-cookie-secret" && local.generated_secrets["cookie"].tags.managed_by == "terraform"
    error_message = "Generated secret metadata is wrong."
  }
  assert {
    condition     = toset(output.managed_secret_names) == toset(["oauth2-proxy-cookie-secret", "other-secret"])
    error_message = "managed_secret_names includes generated secrets."
  }
  assert {
    condition     = toset(keys(local.secret_values)) == toset(keys(local.secrets))
    error_message = "secret_values must have exactly the keys of secrets."
  }
}

run "managed_and_generated_merge" {
  command = plan

  variables {
    managed_secrets       = { db = { name = "db-password" } }
    managed_secret_values = { db = "x" }
    generated_secrets     = { cookie = "cookie-secret" }
  }

  assert {
    condition     = toset(keys(local.secrets)) == toset(["db", "cookie"])
    error_message = "Managed and generated secrets should merge by key."
  }
  assert {
    condition     = length(output.managed_secret_names) == 2
    error_message = "Both kinds should be listed."
  }
}

run "operator_secrets" {
  command = apply

  variables {
    operator_managed_secret_names = ["slack-token", "github-pat"]
    tags                          = { env = "dev" }
  }

  assert {
    condition     = length(azurerm_key_vault_secret.operator_managed) == 2
    error_message = "One placeholder per operator secret name."
  }
  assert {
    condition     = alltrue([for s in azurerm_key_vault_secret.operator_managed : s.value == "REPLACE_ME" && s.tags.managed_by == "operator" && s.tags.env == "dev"])
    error_message = "Placeholders should hold REPLACE_ME and carry operator tags merged with module tags."
  }
  assert {
    condition     = toset(output.operator_secret_names) == toset(["slack-token", "github-pat"])
    error_message = "operator_secret_names output mismatch."
  }
  assert {
    condition     = length(output.managed_secret_names) == 0
    error_message = "Operator secrets are not Terraform-managed values."
  }
  assert {
    condition     = output.uri == "https://kv-test-dev.vault.azure.net/" && endswith(output.resource_id, "/providers/Microsoft.KeyVault/vaults/kv-test-dev") && output.name != ""
    error_message = "Vault name, uri and resource_id outputs should come from the AVM module."
  }
}
