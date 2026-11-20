mock_provider "azurerm" {
  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-gh-test-dev"
      principal_id = "00000000-0000-0000-0000-000000000001"
      client_id    = "00000000-0000-0000-0000-000000000002"
      tenant_id    = "00000000-0000-0000-0000-000000000003"
    }
  }
}


variables {
  name                = "id-gh-test-dev"
  location            = "westeurope"
  resource_group_name = "rg-test"
  repository          = "example-org/example-repo"
}

run "role_assignments" {
  command = apply

  variables {
    role_assignments = {
      acr_push = {
        scope                = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ContainerRegistry/registries/acrtest"
        role_definition_name = "AcrPush"
        description          = "Push images"
      }
      blob = {
        scope                = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Storage/storageAccounts/sttest"
        role_definition_name = "Storage Blob Data Contributor"
      }
    }
  }

  assert {
    condition     = length(azurerm_role_assignment.this) == 2
    error_message = "One role assignment per map entry."
  }

  assert {
    condition     = azurerm_role_assignment.this["acr_push"].scope == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ContainerRegistry/registries/acrtest"
    error_message = "Role scope must be the supplied registry ID."
  }

  assert {
    condition     = azurerm_role_assignment.this["acr_push"].role_definition_name == "AcrPush" && azurerm_role_assignment.this["acr_push"].description == "Push images"
    error_message = "Role name/description must pass through."
  }

  assert {
    condition     = alltrue([for r in azurerm_role_assignment.this : r.principal_id == "00000000-0000-0000-0000-000000000001" && r.principal_type == "ServicePrincipal"])
    error_message = "Roles must go to the identity's principal as ServicePrincipal."
  }

  assert {
    condition     = azurerm_role_assignment.this["blob"].description == null
    error_message = "description defaults to null."
  }
}

run "name_too_short" {
  command = plan
  variables {
    name = "ab"
  }
  expect_failures = [var.name]
}

run "name_bad_leading_char" {
  command = plan
  variables {
    name = "-id-gh-test"
  }
  expect_failures = [var.name]
}

run "name_too_long" {
  command = plan
  variables {
    name = join("", [for i in range(129) : "a"])
  }
  expect_failures = [var.name]
}

run "name_max_length_ok" {
  command = plan
  variables {
    name = join("", [for i in range(128) : "a"])
  }
  assert {
    condition     = output.name == join("", [for i in range(128) : "a"])
    error_message = "128-char name is valid."
  }
}

run "repository_not_owner_name" {
  command = plan
  variables {
    repository = "just-a-name"
  }
  expect_failures = [var.repository]
}

run "repository_extra_segment" {
  command = plan
  variables {
    repository = "a/b/c"
  }
  expect_failures = [var.repository]
}
