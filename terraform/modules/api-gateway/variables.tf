# 프로젝트 이름 변수
variable "project_name" {
  description = "리소스 태그 및 이름에 사용될 프로젝트 이름입니다."
  type        = string
}

# 환경 변수
variable "environment" {
  description = "리소스 태그 및 이름에 사용될 환경 이름입니다 (예: dev, prod)."
  type        = string
}

# ALB DNS 이름 변수
variable "alb_dns_name" {
  description = "API Gateway 통합을 위한 Application Load Balancer의 DNS 이름입니다."
  type        = string
}

# 참고: 스로틀링 설정은 향후 사용량 계획(Usage Plan)에서 관리 예정
# 현재는 기본 기능에 집중하여 변수 제거

# 로그 보존 기간 변수
variable "log_retention_days" {
  description = "CloudWatch 로그 보존 기간(일)입니다."
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "로그 보존 기간은 AWS에서 지원하는 값이어야 합니다."
  }
}
