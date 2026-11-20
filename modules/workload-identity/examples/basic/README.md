# basic example

Creates a user-assigned identity federated to one Kubernetes service account, with DNS Zone Contributor on a zone.
Validate offline with `terraform init -backend=false && terraform validate`.
Applying needs real Azure credentials, a real subscription ID and a real cluster issuer URL (the values in `main.tf` are placeholders).
