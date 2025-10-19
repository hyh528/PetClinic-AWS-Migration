# =============================================================================
# 공통 Backend 설정 - 모든 레이어에서 공유 (Oregon 리전)
# =============================================================================
# 사용법: terraform init -backend-config="../backend.hcl"

bucket         = "petclinic-tfstate-oregon-dev"
region         = "us-west-2"
encrypt        = true
# dynamodb_table = "petclinic-tf-locks-oregon-dev"  # S3 네이티브 잠금 사용