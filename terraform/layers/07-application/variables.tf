# =============================================================================
# Application Layer Variables - 공유 변수 시스템 활용 (단순화됨)
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
  default     = <<EOF
[
  {
    "name": "petclinic-app",
    "image": "nginx:latest",
    "cpu": 256,
    "memory": 512,
    "essential": true,
    "portMappings": [
      {
        "containerPort": 8080,
        "hostPort": 8080,
        "protocol": "tcp"
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/petclinic-dev-app",
        "awslogs-region": var.shared_config.aws_region,
        "awslogs-stream-prefix": "ecs"
      }
    }
  }
]
EOF
}