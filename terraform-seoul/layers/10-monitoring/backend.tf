terraform {
  # Backend 설정은 init 시 주입: terraform init -backend-config=../../backend.hcl -backend-config=backend.config
  backend "s3" {}
}
