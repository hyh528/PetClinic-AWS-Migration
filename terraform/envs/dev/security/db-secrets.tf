# dev 환경의 데이터베이스 자격 증명을 위한 Secrets Manager 시크릿 생성
# 담당: 보안팀

# ------------------------------------------------------------------------------
# 변수 선언
# ------------------------------------------------------------------------------

variable "db_username" {
  description = "데이터베이스 사용자 이름"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "데이터베이스 비밀번호"
  type        = string
  sensitive   = true
}

# 이 시크릿을 암호화할 KMS 키 ID (필요시 security 폴더의 kms.tf 등에서 생성/참조)
variable "kms_key_id_for_db" {
  description = "DB 시크릿 암호화에 사용할 KMS 키 ARN"
  type        = string
  default     = null # null일 경우 AWS 관리형 키 사용
}

# ------------------------------------------------------------------------------
# 로컬 변수 (시크릿 값 구성)
# ------------------------------------------------------------------------------

locals {
  # 시크릿 매니저에 저장될 값 (JSON 형식)
  db_secret_values = {
    username = var.db_username
    password = var.db_password
  }
}

# ------------------------------------------------------------------------------
# 모듈 호출
# ------------------------------------------------------------------------------

module "db_credentials_secret" {
  # 모듈 소스 경로 (루트에서부터의 상대 경로)
  source = "../../../modules/secrets-manager"

  # 모듈에 전달할 변수
  secret_name        = "dev/rds/credentials"
  secret_description = "개발 환경 RDS 데이터베이스의 자격 증명"
  project_name       = "petclinic"
  environment        = "dev"
  kms_key_id         = var.kms_key_id_for_db

  # 초기 버전 생성 및 값 설정
  create_initial_version = true
  secret_string_value    = jsonencode(local.db_secret_values)
}