# ==========================================
# ECS 모듈 변수 정의
# ==========================================
# 변수 분리 및 검증

variable "cluster_name" {
  description = "ECS 클러스터 이름"
  type        = string

  validation {
    condition     = length(var.cluster_name) > 0 && length(var.cluster_name) <= 255
    error_message = "클러스터 이름은 1-255자 사이여야 합니다."
  }
}

variable "task_family" {
  description = "ECS 태스크 패밀리 이름"
  type        = string

  validation {
    condition     = length(var.task_family) > 0 && length(var.task_family) <= 255
    error_message = "태스크 패밀리 이름은 1-255자 사이여야 합니다."
  }
}

variable "execution_role_arn" {
  description = "ECS 태스크 실행 역할 ARN"
  type        = string

  validation {
    condition     = startswith(var.execution_role_arn, "arn:aws:iam::")
    error_message = "유효한 IAM 역할 ARN이어야 합니다."
  }
}

variable "container_definitions" {
  description = "컨테이너 정의 (JSON 형식)"
  type        = string

  validation {
    condition     = length(var.container_definitions) > 0
    error_message = "컨테이너 정의는 비어있을 수 없습니다."
  }
}

variable "cpu" {
  description = "태스크 CPU 유닛"
  type        = string
  default     = "256"

  validation {
    condition     = contains(["256", "512", "1024", "2048", "4096"], var.cpu)
    error_message = "CPU는 256, 512, 1024, 2048, 4096 중 하나여야 합니다."
  }
}

variable "memory" {
  description = "태스크 메모리 (MB)"
  type        = string
  default     = "512"

  validation {
    condition     = contains(["512", "1024", "2048", "3072", "4096", "5120", "6144", "7168", "8192"], var.memory)
    error_message = "메모리는 지정된 값 중 하나여야 합니다."
  }
}

variable "desired_count" {
  description = "실행할 태스크 수"
  type        = number
  default     = 2

  validation {
    condition     = var.desired_count > 0 && var.desired_count <= 10
    error_message = "태스크 수는 1-10개 사이여야 합니다."
  }
}

variable "subnets" {
  description = "프라이빗 서브넷 ID 목록"
  type        = list(string)

  validation {
    condition     = length(var.subnets) >= 1
    error_message = "최소 하나의 서브넷이 필요합니다."
  }
}

variable "security_groups" {
  description = "보안 그룹 ID 목록"
  type        = list(string)
  default     = []
}

variable "target_group_arn" {
  description = "ALB 대상 그룹 ARN"
  type        = string

  validation {
    condition     = startswith(var.target_group_arn, "arn:aws:elasticloadbalancing::")
    error_message = "유효한 ALB 대상 그룹 ARN이어야 합니다."
  }
}

variable "container_name" {
  description = "ALB와 연결할 컨테이너 이름"
  type        = string

  validation {
    condition     = length(var.container_name) > 0
    error_message = "컨테이너 이름은 비어있을 수 없습니다."
  }
}

variable "container_port" {
  description = "컨테이너 포트"
  type        = number
  default     = 8080

  validation {
    condition     = var.container_port > 0 && var.container_port <= 65535
    error_message = "포트는 1-65535 사이여야 합니다."
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
}var
iable "task_role_arn" {
  description = "ECS 태스크 역할 ARN (선택사항)"
  type        = string
  default     = null

  validation {
    condition     = var.task_role_arn == null || startswith(var.task_role_arn, "arn:aws:iam::")
    error_message = "유효한 IAM 역할 ARN이어야 합니다."
  }
}