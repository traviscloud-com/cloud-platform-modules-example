mock_provider "azuread" {
  mock_resource "azuread_application" {
    defaults = {
      client_id = "11111111-1111-1111-1111-111111111111"
      object_id = "22222222-2222-2222-2222-222222222222"
      id        = "/applications/22222222-2222-2222-2222-222222222222"
    }
  }
  mock_resource "azuread_service_principal" {
    defaults = {
      object_id = "33333333-3333-3333-3333-333333333333"
    }
  }
  mock_resource "azuread_application_password" {
    defaults = {
      value = "mock-secret"
    }
  }
}

mock_provider "time" {
  mock_resource "time_rotating" {
    defaults = {
      id               = "2030-01-01T00:00:00Z"
      rotation_rfc3339 = "2030-01-01T00:00:00Z"
    }
  }
}

variables {
  display_name     = "sp-test"
  description      = "Test principal"
  owner_object_ids = ["00000000-0000-0000-0000-000000000000"]
}

run "defaults" {
  command = apply

  assert {
    condition     = azuread_application.this.display_name == "sp-test" && azuread_application.this.sign_in_audience == "AzureADMyOrg"
    error_message = "Application should be single-tenant with the given name."
  }
  assert {
    condition     = azuread_application.this.prevent_duplicate_names == true
    error_message = "prevent_duplicate_names must be on."
  }
  assert {
    condition     = azuread_service_principal.this.app_role_assignment_required == false
    error_message = "Assignment must not be required."
  }
  assert {
    condition     = azuread_service_principal.this.client_id == azuread_application.this.client_id
    error_message = "SP must be bound to the application client_id."
  }
  assert {
    condition     = time_rotating.secret.rotation_days == 730
    error_message = "Default rotation is 730 days."
  }
  assert {
    condition     = azuread_application_password.this.display_name == "client secret (terraform, 730d)"
    error_message = "Unexpected default secret display name."
  }
  assert {
    condition     = strcontains(azuread_application.this.notes, "730 days")
    error_message = "Notes should state the lifetime."
  }
  assert {
    condition     = azuread_application_password.this.rotate_when_changed["rotation"] == time_rotating.secret.id
    error_message = "Password must rotate with time_rotating."
  }
  assert {
    condition     = azuread_application_password.this.end_date == time_rotating.secret.rotation_rfc3339
    error_message = "end_date must follow the rotation timestamp."
  }
  assert {
    condition     = output.client_id == "11111111-1111-1111-1111-111111111111" && output.object_id == "33333333-3333-3333-3333-333333333333" && output.application_object_id == "22222222-2222-2222-2222-222222222222"
    error_message = "Outputs must map to the right resource attributes."
  }
  assert {
    condition     = output.client_secret == "mock-secret"
    error_message = "client_secret output should expose the password value."
  }
  assert {
    condition     = output.secret_end_date == time_rotating.secret.rotation_rfc3339
    error_message = "secret_end_date output mismatch."
  }
}

run "custom_rotation_and_names" {
  command = apply

  variables {
    secret_rotation_days = 90
    secret_display_name  = "eso"
    owner_object_ids     = ["00000000-0000-0000-0000-000000000000", "00000000-0000-0000-0000-000000000001"]
  }

  assert {
    condition     = time_rotating.secret.rotation_days == 90
    error_message = "rotation_days not propagated."
  }
  assert {
    condition     = azuread_application_password.this.display_name == "eso (terraform, 90d)"
    error_message = "Secret display name should embed name and days."
  }
  assert {
    condition     = strcontains(azuread_application.this.notes, "90 days")
    error_message = "Notes should reflect 90 days."
  }
  assert {
    condition     = length(azuread_application.this.owners) == 2 && length(azuread_service_principal.this.owners) == 2
    error_message = "Owners must be applied to both app and SP."
  }
}

run "rotation_minimum_boundary" {
  command = plan

  variables {
    secret_rotation_days = 1
  }

  assert {
    condition     = time_rotating.secret.rotation_days == 1
    error_message = "1 day is a valid lifetime."
  }
}

run "rotation_zero_rejected" {
  command = plan

  variables {
    secret_rotation_days = 0
  }

  expect_failures = [var.secret_rotation_days]
}

run "rotation_negative_rejected" {
  command = plan

  variables {
    secret_rotation_days = -5
  }

  expect_failures = [var.secret_rotation_days]
}
