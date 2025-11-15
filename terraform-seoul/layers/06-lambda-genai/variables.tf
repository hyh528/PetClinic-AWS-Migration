# =============================================================================
# Lambda GenAI Layer Variables
# =============================================================================
# 목적: 레이어 전용 변수만 정의 (공통 변수는 common 모듈에서 상속)

# =============================================================================
# 공통 변수 (common 모듈에서 상속)
# =============================================================================

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
# =============================================================================
# 백엔드 설정 변수
# =============================================================================

variable "backend_bucket" {
  description = "Terraform 상태 파일을 저장할 S3 버킷"
  type        = string
}

# =============================================================================
# Lambda GenAI 모듈 변수들
# =============================================================================

# Bedrock 설정
variable "bedrock_model_id" {
  description = "사용할 Bedrock 모델 ID"
  type        = string
  default     = "anthropic.claude-3-haiku-20240307-v1:0"
}

# 데이터베이스 설정
variable "db_user" {
  description = "데이터베이스 사용자명"
  type        = string
  default     = "petclinic"
}

variable "db_name" {
  description = "데이터베이스 이름"
  type        = string
  default     = "petclinic"
}

variable "db_port" {
  description = "데이터베이스 포트"
  type        = string
  default     = "3306"
}

# VPC 설정 변수들 (다른 레이어에서 가져오므로 여기서는 정의만)
# 실제 값은 data source에서 가져옴
