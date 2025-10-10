# =============================================================================
# Lambda GenAI Layer Variables - 공유 변수 시스템 적용 (단순화됨)
# =============================================================================
# 목적: shared-variables.tf에서 정의된 공통 변수를 사용하여 일관성 확보

# 공유 설정 (shared-variables.tf에서 전달)
variable "shared_config" {
  description = "공유 설정 정보 (shared-variables.tf에서 전달)"
  type = object({
    name_prefix = string
    environment = string
    aws_region  = string
    aws_profile = string
    common_name = string
    common_tags = map(string)
  })
}

# 상태 관리 설정 (shared-variables.tf에서 전달)
variable "state_config" {
  description = "Terraform 상태 관리 설정 (shared-variables.tf에서 전달)"
  type = object({
    bucket_name = string
    region      = string
    profile     = string
  })
}

# =============================================================================
# Lambda GenAI 레이어 특화 변수 (단순화)
# =============================================================================

# Bedrock 설정 (기본값만)
variable "bedrock_model_id" {
  description = "사용할 Bedrock 모델 ID"
  type        = string
  default     = "anthropic.claude-3-haiku-20240307-v1:0"
}
