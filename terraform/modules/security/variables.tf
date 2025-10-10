variable "name_prefix" {
  description = "리소스 이름 접두사, 예: petclinic-dev"
  type        = string
}

variable "environment" {
  description = "환경 레이블, 예: dev|stg|prd"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "alb_security_group_id" {
  description = "ALB 보안 그룹 ID (ECS 태스크로의 인그레스 소스). ALB->ECS 인그레스 규칙 생성을 건너뛰려면 비워두세요."
  type        = string
  default     = ""
}

variable "vpce_security_group_id" {
  description = "VPC 인터페이스 엔드포인트 보안 그룹 ID (ECS에서 443으로 송신할 대상). 비어 있으면 0.0.0.0/0:443이 허용됩니다."
  type        = string
  default     = ""
}

variable "ecs_task_port" {
  description = "ECS 태스크가 수신하는 애플리케이션 포트"
  type        = number
  default     = 8080
}

variable "rds_port" {
  description = "데이터베이스 포트 (MySQL의 기본값 3306)"
  type        = number
  default     = 3306
}

variable "tags" {
  description = "공통 리소스 태그"
  type        = map(string)
  default     = {}
}

# IAM 정책용 추가 변수
variable "aws_region" {
  description = "AWS 리전 (IAM 정책 ARN 생성용)"
  type        = string
}