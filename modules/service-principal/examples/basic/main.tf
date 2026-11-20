provider "azuread" {
  # Placeholder tenant; supply the real one via ARM_TENANT_ID / az login.
  tenant_id = "00000000-0000-0000-0000-000000000000"
}

provider "time" {}

module "service_principal" {
  source = "../.."

  display_name = "sp-example-workload"
  description  = "Example workload that cannot use federated credentials."
  owner_object_ids = [
    "00000000-0000-0000-0000-000000000000", # applying principal (placeholder)
  ]

  secret_rotation_days = 365
}
