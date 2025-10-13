# =============================================================================
# Parameter Store Layer Variables
# =============================================================================
# 목적: 레이어 전용 변수만 정의 (공통 변수는 shared/common.tfvars에서 로드)

# =============================================================================
# 공통 변수 (shared/common.tfvars에서 로드)
# =============================================================================

variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "name_prefix" {
  description = "모든 리소스 이름의 접두사"
  type        = string
}

variable "environment" {
  description = "배포 환경 (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS 리전"
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI 프로파일"
  type        = string
}

variable "tags" {
  description = "모든 리소스에 적용할 공통 태그"
  type        = map(string)
}

variable "tfstate_bucket_name" {
  description = "Terraform 상태 파일을 저장하는 S3 버킷 이름"
  type        = string
}

# =============================================================================
# Parameter Store 레이어 전용 변수 (애플리케이션용)
# =============================================================================

# Parameter Store 기본 설정
variable "parameter_prefix" {
  description = "Parameter Store 기본 접두사 설정"
  type        = string
  default     = "/petclinic"
}

variable "database_username" {
  description = "데이터베이스 사용자명"
  type        = string
  default     = "petclinic"
}

# 기본 파라미터만 우선 (복잡한 설정 제거)
variable "enable_sql_logging" {
  description = "SQL 로깅 활성화 여부 (개발 환경용)"
  type        = bool
  default     = false
}