# =============================================================================
# Application Layer Variables - 공유 변수 사용
# =============================================================================
# 설명: shared-variables.tf에서 정의된 공유 변수를 사용하여 중복 제거

# =============================================================================
# ECR 관련 변수
# =============================================================================

variable "repository_name" {
  description = "ECR 리포지토리 이름"
  type        = string
  default     = null
}

# =============================================================================
# ECS 관련 변수
# =============================================================================

variable "cluster_name" {
  description = "ECS 클러스터 이름"
  type        = string
  default     = null
}

variable "task_family" {
  description = "ECS 태스크 패밀리 이름"
  type        = string
  default     = null
}

variable "container_name" {
  description = "컨테이너 이름"
  type        = string
  default     = "petclinic-app"
}

variable "container_port" {
  description = "컨테이너 포트"
  type        = number
  default     = 8080
}

variable "container_definitions" {
  description = "ECS 컨테이너 정의 (JSON 형식)"
  type        = string
  default     = null
}