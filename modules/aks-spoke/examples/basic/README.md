# basic example

Creates one AKS stamp (spoke VNet, hub peering, cluster) with the module defaults.
The hub VNet ID and name in `main.tf` are placeholders for an existing hub (see `modules/hub`).
Validate offline with `terraform init -backend=false && terraform validate`.
Applying needs real Azure credentials and a real subscription ID (the one in `main.tf` is a placeholder).
