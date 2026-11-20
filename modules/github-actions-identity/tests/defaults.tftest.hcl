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

run "defaults" {
  command = apply

  assert {
    condition     = output.federated_subjects == ["repo:example-org/example-repo:ref:refs/heads/main"]
    error_message = "Default subject must be the main branch under repo:<repository>."
  }

  assert {
    condition     = output.name == "id-gh-test-dev"
    error_message = "name output must echo the input."
  }

  assert {
    condition     = output.principal_id == "00000000-0000-0000-0000-000000000001" && output.client_id == "00000000-0000-0000-0000-000000000002"
    error_message = "principal_id/client_id must pass through from the AVM module."
  }

  assert {
    condition     = length(azurerm_role_assignment.this) == 0
    error_message = "No role assignments by default."
  }

}

run "tags" {
  command = apply

  variables {
    tags = { environment = "dev" }
  }

  assert {
    condition     = module.identity.resource.tags["environment"] == "dev"
    error_message = "Tags must reach the identity."
  }

  assert {
    condition     = module.identity.resource.name == "id-gh-test-dev" && module.identity.resource.resource_group_name == "rg-test"
    error_message = "Identity name and resource group must reach the AVM module."
  }
}
