# basic example

Creates a dev hub in westus3 with every optional service off (no firewall, DNS resolver or bastion).
Validate offline with `terraform init -backend=false && terraform validate`.
Applying needs real Azure credentials and a real subscription ID (the one in `main.tf` is a placeholder).
