# Basic example

Mints one Entra application + service principal with a Terraform-rotated
client secret (365 days). All IDs are all-zeros placeholders; replace
`owner_object_ids` and the tenant before applying.

```sh
terraform init -backend=false
terraform validate
```
