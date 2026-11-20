# basic

Minimal `local-cluster`: resource group, Key Vault (RBAC) and the External
Secrets service principal. ACR is off and no DNS secrets are present.

Subscription and tenant IDs are all-zero placeholders; replace them (or use
`ARM_SUBSCRIPTION_ID` / `ARM_TENANT_ID`) before a real apply.

To add a registry, set `enable_acr = true` and
`acr_push_repositories = { app = { repository = "owner/app" } }`.
To add blob storage, set `enable_storage = true` and
`storage_containers = ["argo-workflows"]`.

```sh
terraform init -backend=false
terraform validate
```
