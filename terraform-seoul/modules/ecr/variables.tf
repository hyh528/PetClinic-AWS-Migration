# ==========================================
# ECR 모듈 변수 정의
# ==========================================
# 변수 분리 및 기본값 설정

variable "repository_name" {
  description = "ECR 리포지토리 이름"
  type        = string
  validation {
    condition     = length(var.repository_name) > 0 && length(var.repository_name) <= 256
    error_message = "리포지토리 이름은 1-256자 사이여야 합니다."
  }
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
  default     = {}

  validation {
    condition     = length(var.tags) <= 50
    error_message = "태그는 최대 50개까지 설정 가능합니다."
  }
}

variable "image_tag_mutability" {
  description = "이미지 태그 변경 가능 여부"
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability는 'MUTABLE' 또는 'IMMUTABLE'만 가능합니다."
  }
}

variable "scan_on_push" {
  description = "이미지 푸시 시 자동 스캔 활성화"
  type        = bool
  default     = true
}

variable "lifecycle_policy_rules" {
  description = "라이프사이클 정책 규칙 목록"
  type = list(object({
    rulePriority = number
    description  = string
    selection = object({
      tagStatus   = string
      countType   = string
      countNumber = number
    })
    action = object({
      type = string
    })
  }))
  default = [
    {
      rulePriority = 1
      description  = "최신 10개 이미지만 보존"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }
  ]
}