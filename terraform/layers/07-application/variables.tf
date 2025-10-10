# =============================================================================
# Application Layer Variables - 모듈 관련 변수만
# =============================================================================

# 기본 프로젝트 정보
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

# 공통 태그
variable "tags" {
  description = "모든 리소스에 적용할 공통 태그"
  type        = map(string)
}

# Terraform 상태 관리
variable "tfstate_bucket_name" {
  description = "Terraform 상태 파일을 저장하는 S3 버킷 이름"
  type        = string
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
  default     = null
}