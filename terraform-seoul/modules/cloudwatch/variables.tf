# ==========================================
# CloudWatch 모듈 변수 정의
# ==========================================

variable "dashboard_name" {
  description = "CloudWatch 대시보드 이름"
  type        = string
  default     = "PetClinic-Monitoring"
}

variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "api_gateway_name" {
  description = "API Gateway 이름"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS 클러스터 이름"
  type        = string
}

variable "ecs_service_name" {
  description = "ECS 서비스 이름 (레거시, 단일 서비스용)"
  type        = string
  default     = ""
}

variable "ecs_services" {
  description = "ECS 서비스 목록 (멀티 서비스 지원)"
  type = map(object({
    service_name = string
  }))
  default = {}
}

variable "lambda_function_name" {
  description = "Lambda 함수 이름"
  type        = string
}

variable "aurora_cluster_name" {
  description = "Aurora 클러스터 이름"
  type        = string
}

variable "alb_name" {
  description = "Application Load Balancer 이름 (레거시)"
  type        = string
  default     = ""
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix (CloudWatch 메트릭용)"
  type        = string
  default     = ""
}

variable "target_groups" {
  description = "타겟 그룹 ARN suffixes (멀티 서비스 지원)"
  type = map(object({
    arn_suffix = string
  }))
  default = {}
}

variable "log_retention_days" {
  description = "CloudWatch 로그 보관 기간 (일)"
  type        = number
  default     = 30
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
  default     = {}
}

variable "sns_topic_arn" {
  description = "알람 알림을 위한 SNS 토픽 ARN (선택사항)"
  type        = string
  default     = null
}