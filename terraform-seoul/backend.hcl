# =============================================================================
# Backend 설정 - 모든 레이어에서 공유 (ap-northeast-2 Seoul)
# =============================================================================
# 사용법: terraform init -backend-config=../../backend.hcl -backend-config=backend.config
#
# S3 네이티브 state locking 사용 (DynamoDB 불필요)

bucket  = "petclinic-tfstate-seoul-dev"
region  = "ap-northeast-2"
encrypt = true