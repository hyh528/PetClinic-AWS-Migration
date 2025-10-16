# =============================================================================
# Application Layer Variables
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

variable "service_image_map" {
  description = <<EOF
Map of service key -> full image reference (including tag or digest).
예: { customers = "123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/petclinic-customers:sha-abc123" }
CI에서 빌드 후 이 값을 생성하여 Terraform 실행에 전달하세요.
EOF
  type    = map(string)
  default = {}
}