# Lambda GenAI 모듈 변수 정의 - 단순화됨

# 기본 설정
variable "name_prefix" {
  description = "리소스 이름 접두사"
  type        = string
}

variable "environment" {
  description = "환경 이름 (dev, staging, prod)"
  type        = string
}

# Bedrock 설정 (기본값만)
variable "bedrock_model_id" {
  description = "사용할 Bedrock 모델 ID"
  type        = string
  default     = "anthropic.claude-3-haiku-20240307-v1:0"
}

# 태그
variable "tags" {
  description = "리소스에 적용할 공통 태그"
  type        = map(string)
  default     = {}
}