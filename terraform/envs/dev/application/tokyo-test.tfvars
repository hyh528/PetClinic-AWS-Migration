# 도쿄 리전 테스트용 변수 파일 - Application 레이어
# 영현님 개인 테스트 환경

# 리전 변경: 서울 -> 도쿄
aws_region = "ap-northeast-1"
aws_profile = "petclinic-yeonghyeon"

# 다른 레이어 상태 참조도 같은 프로필 사용
network_state_profile = "petclinic-yeonghyeon"
database_state_profile = "petclinic-yeonghyeon"
security_state_profile = "petclinic-yeonghyeon"

# 테스트 환경 식별
name_prefix = "petclinic-tokyo-test"
environment = "test"

# Terraform 상태 관리 (기존과 동일)
tfstate_bucket_name = "petclinic-tfstate-team-jungsu-kopo"
tf_lock_table_name = "petclinic-tfstate-lock"
encrypt_state = true

# 테스트 태그
tags = {
  Purpose = "tokyo-region-test"
  Owner   = "yeonghyeon"
  TestEnv = "true"
}