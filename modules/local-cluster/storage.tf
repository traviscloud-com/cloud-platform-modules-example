# Blob storage for workloads on the local cluster (workflow artifacts, logs).
#   st<prefix><env>                 Standard LRS, the cheapest redundancy
#   containers                      one per storage_containers entry, private
#   sp-storage-<env>                Storage Blob Data Contributor on those
#                                   containers only; its client secret and the
#                                   identifiers a client needs go into the
#                                   vault, External Secrets syncs them in
# Entra RBAC can be scoped to a single container, so the cluster gets a
# service principal (same shape as sp-eso-<env>) and shared-key access to the
# account stays off: there is no account key to leak.

locals {
  storage_account_name = coalesce(var.storage_account_name, "st${var.name_prefix}${var.environment}")
  storage_containers   = var.enable_storage ? toset(var.storage_containers) : toset([])
  storage_sp_present   = var.enable_storage && length(var.storage_containers) > 0
}

# tflint-ignore: azurerm_resources_missing_prevent_destroy
resource "azurerm_storage_account" "this" {
  count = var.enable_storage ? 1 : 0

  name                     = local.storage_account_name
  location                 = var.location
  resource_group_name      = azurerm_resource_group.this.name
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = var.tags

  # Identity-only access: no shared keys, no anonymous blobs. The endpoint is
  # public because the cluster is outside Azure; the data plane is Entra RBAC.
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  allow_nested_items_to_be_public = false
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
}

resource "azurerm_storage_container" "this" {
  for_each = local.storage_containers

  name                  = each.key
  storage_account_id    = azurerm_storage_account.this[0].id
  container_access_type = "private"
}

# Blobs are deleted storage_retention_days after their last modification, so
# the account does not grow without bound. 0 keeps everything.
resource "azurerm_storage_management_policy" "retention" {
  count = var.enable_storage && var.storage_retention_days > 0 ? 1 : 0

  storage_account_id = azurerm_storage_account.this[0].id

  rule {
    name    = "delete-after-${var.storage_retention_days}-days"
    enabled = true

    filters {
      blob_types = ["blockBlob"]
    }

    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = var.storage_retention_days
      }
    }
  }
}

# --- The cluster's identity for the containers --------------------------------

module "storage_principal" {
  count = local.storage_sp_present ? 1 : 0

  source = "../service-principal"

  display_name         = "sp-storage-${var.environment}"
  description          = "Workloads on the ${var.environment} cluster: read and write blobs in ${local.storage_account_name} (${join(", ", sort(var.storage_containers))}) only"
  owner_object_ids     = local.owners
  secret_rotation_days = var.secret_rotation_days
  secret_display_name  = "blob-storage"
}

resource "azurerm_role_assignment" "storage" {
  for_each = local.storage_sp_present ? local.storage_containers : toset([])

  scope                            = azurerm_storage_container.this[each.key].id
  role_definition_name             = "Storage Blob Data Contributor"
  principal_id                     = module.storage_principal[0].object_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
  description                      = "Workloads on the ${var.environment} cluster read and write blobs in container ${each.key}"
}

locals {
  # Vault secrets for the storage client. Keys depend only on non-sensitive
  # toggles so the key-vault module's for_each is known at plan time.
  storage_secrets = local.storage_sp_present ? {
    storage_blob_endpoint = {
      name         = "storage-blob-endpoint"
      content_type = "text/plain"
      tags         = { consumer = "blob storage clients", source = "modules/local-cluster storage.tf" }
    }
    storage_sp_tenant_id = {
      name         = "storage-sp-tenant-id"
      content_type = "text/plain"
      tags         = { consumer = "blob storage clients", source = "modules/local-cluster storage.tf" }
    }
    storage_sp_client_id = {
      name         = "storage-sp-client-id"
      content_type = "text/plain"
      tags         = { consumer = "blob storage clients", source = "modules/local-cluster storage.tf" }
    }
    storage_sp_client_secret = {
      name         = "storage-sp-client-secret"
      content_type = "text/plain"
      tags         = { consumer = "blob storage clients", source = "modules/local-cluster storage.tf" }
    }
  } : {}
  storage_secret_values = local.storage_sp_present ? {
    storage_blob_endpoint    = azurerm_storage_account.this[0].primary_blob_endpoint
    storage_sp_tenant_id     = data.azuread_client_config.current.tenant_id
    storage_sp_client_id     = module.storage_principal[0].client_id
    storage_sp_client_secret = module.storage_principal[0].client_secret
  } : {}
}
