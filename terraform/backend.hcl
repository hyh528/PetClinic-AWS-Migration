# =============================================================================
# 공통 Backend 설정 - 모든 레이어에서 공유
# =============================================================================
# 사용법: terraform init -backend-config="../backend.hcl"

bucket         = "petclinic-tfstate-sydney-dev"
region         = "ap-southeast-2"
encrypt        = true
dynamodb_table = "petclinic-tf-locks-sydney-dev"