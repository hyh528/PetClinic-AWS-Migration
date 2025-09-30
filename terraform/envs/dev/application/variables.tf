# ==========================================
# Application 환경 공통 변수 선언
# ==========================================
# - 모든 백엔드/프로바이더/원격상태 접근에 필요한 변수들을 한 곳에 선언
# - 값은 terraform/backend.tfvars 또는 -var-file로 주입
# - 프로파일은 기본값을 제공하되 필요 시 override 가능

# 백엔드(S3/DynamoDB) 공통
variable "tfstate_bucket_name" {
  description = "Terraform 원격 상태 보관용 S3 버킷 이름"
  type        = string
}

variable "tf_lock_table_name" {
  description = "Terraform 상태 잠금을 위한 DynamoDB 테이블 이름"
  type        = string
}

variable "aws_region" {
  description = "리소스를 배포할 AWS 리전 (예: ap-northeast-2)"
  type        = string
}

variable "encrypt_state" {
  description = "원격 상태 암호화 사용 여부"
  type        = bool
}

# 이 환경에서 리소스를 생성/변경하는 기본 AWS CLI 프로파일
variable "aws_profile" {
  description = "Application 레이어에서 사용하는 기본 AWS CLI 프로파일"
  type        = string
  default     = "petclinic-seokgyeom"
}

# 원격 상태 접근 프로파일(크로스-어카운트/크로스-프로파일을 위한 분리)
variable "network_state_profile" {
  description = "Network 레이어 원격 상태(S3) 접근을 위한 AWS CLI 프로파일"
  type        = string
  default     = "petclinic-yeonghyeon"
}

variable "database_state_profile" {
  description = "Database 레이어 원격 상태(S3) 접근을 위한 AWS CLI 프로파일"
  type        = string
  default     = "petclinic-junje"
}

variable "security_state_profile" {
  description = "Security 레이어 원격 상태(S3) 접근을 위한 AWS CLI 프로파일"
  type        = string
  default     = "petclinic-hwigwon"
}