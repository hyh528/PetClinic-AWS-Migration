# =============================================================================
# Lambda GenAI Layer Variables - 공유 변수 시스템 활용 (단순화됨)
# =============================================================================
# 목적: shared-variables.tf에서 정의된 공유 변수들을 활용하여 설정을 단순화
# 공유 설정 (shared-variables.tf에서 가져옴)
variable "shared_config" {
  description = "공유 설정 변수들 (shared-variables.tf에서 가져옴)"
  type = object({
    name_prefix = string
    environment = string
    aws_region  = string
    aws_profile = string
    common_name = string
    common_tags = map(string)
  })
}
# 상태 관리 설정 (shared-variables.tf에서 가져옴)
variable "state_config" {
  description = "Terraform 상태 관리 설정 (shared-variables.tf에서 가져옴)"
  type = object({
    bucket_name = string
    region      = string
    profile     = string
  })
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
