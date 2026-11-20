# basic example

Creates a dev Key Vault with one generated secret and one operator-set placeholder.
Validate offline with `terraform init -backend=false && terraform validate`.
Applying needs real Azure credentials and a real subscription ID (the one in `main.tf` is a placeholder).
