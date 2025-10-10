# Parameter Store 레이어 개발 환경 변수
# 단일 책임: Parameter Store 설정만 관리

# 기본 설정
name_prefix = "petclinic-dev"
environment = "dev"
aws_region  = "ap-northeast-2"

# Terraform 상태 관리
tfstate_bucket_name = "petclinic-tfstate-team-jungsu-kopo"

# 다른 레이어 상태 파일 접근 프로필
network_state_profile     = "petclinic-yeonghyeon"
application_state_profile = "petclinic-seokgyeom"

# Parameter Store 설정
parameter_prefix   = "/petclinic"
database_username  = "petclinic"
enable_sql_logging = true  # 개발 환경에서는 SQL 로깅 활성화

# 암호화 설정
kms_key_id  = "alias/aws/ssm"  # 기본 SSM KMS 키 사용
kms_key_arn = ""               # 기본 키 사용 시 비워둠

# IAM 설정
create_iam_policy = true  # ECS 태스크에서 사용할 IAM 정책 생성

# 로깅 설정
enable_access_logging = false  # 개발 환경에서는 비활성화
log_retention_days    = 30

# 고급 설정
parameter_tier  = "Standard"  # 개발 환경에서는 Standard 티어 사용
allowed_pattern = ""          # 패턴 제한 없음
data_type      = "text"

# AWS 프로필
aws_profile = "petclinic-seokgyeom"

# 태그
tags = {
  Project     = "petclinic"
  Environment = "dev"
  ManagedBy   = "terraform"
  Layer       = "parameter-store"
  Owner       = "team-petclinic"
  CostCenter  = "training"
  Purpose     = "spring-cloud-config-replacement"
}