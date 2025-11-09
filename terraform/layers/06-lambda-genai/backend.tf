terraform {
  # Backend configuration injected via: terraform init -backend-config=../../backend.hcl -backend-config=backend.config
  backend "s3" {}
}
