# =============================================================================
# 공통 Backend 설정 - 모든 레이어에서 공유
# =============================================================================
# 사용법: terraform init -backend-config="../backend.hcl"

bucket         = "petclinic-yeonghyeon-test"
region         = "ap-northeast-1"
encrypt        = true
dynamodb_table = "petclinic-yeonghyeon-test-locks"