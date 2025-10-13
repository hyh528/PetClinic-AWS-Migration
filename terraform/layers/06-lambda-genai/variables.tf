# =============================================================================
# Lambda GenAI Layer Variables
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
# Lambda GenAI 모듈 변수들 (단순화됨)
# =============================================================================
# Bedrock 설정 (안정적인 기본값)
variable "bedrock_model_id" {
  description = "사용할 Bedrock 모델 ID"
  type        = string
  default     = "anthropic.claude-3-sonnet-20240229-v1:0"
}
