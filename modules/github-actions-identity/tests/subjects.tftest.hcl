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

run "branch_tag_environment_pull_request" {
  command = apply

  variables {
    subjects = [
      "ref:refs/heads/main",
      "ref:refs/tags/v1.2.3",
      "environment:prod",
      "pull_request",
    ]
  }

  assert {
    condition = toset(output.federated_subjects) == toset([
      "repo:example-org/example-repo:ref:refs/heads/main",
      "repo:example-org/example-repo:ref:refs/tags/v1.2.3",
      "repo:example-org/example-repo:environment:prod",
      "repo:example-org/example-repo:pull_request",
    ])
    error_message = "Each subject suffix must be prefixed with repo:<repository>."
  }

}

run "immutable_subject_prefix" {
  command = apply

  variables {
    subject_prefix = "repo:example-org@1234/example-repo@5678"
    subjects       = ["environment:prod"]
  }

  assert {
    condition     = output.federated_subjects == ["repo:example-org@1234/example-repo@5678:environment:prod"]
    error_message = "Custom subject_prefix must replace repo:<repository>."
  }
}

run "empty_prefix_falls_back" {
  command = apply

  variables {
    subject_prefix = ""
  }

  assert {
    condition     = output.federated_subjects == ["repo:example-org/example-repo:ref:refs/heads/main"]
    error_message = "Empty subject_prefix must fall back to repo:<repository>."
  }
}

run "long_subject_name_truncated" {
  command = apply

  variables {
    subjects = ["ref:refs/heads/feature/${join("-", [for i in range(30) : "segment"])}"]
  }

}

run "too_many_subjects" {
  command = plan

  variables {
    subjects = [for i in range(21) : "environment:e${i}"]
  }

  expect_failures = [var.subjects]
}

run "no_subjects" {
  command = plan

  variables {
    subjects = []
  }

  expect_failures = [var.subjects]
}
