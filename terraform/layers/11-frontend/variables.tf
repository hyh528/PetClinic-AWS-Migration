# Frontend Hosting Layer Variables

variable "name_prefix" {
  description = "리소스 이름 접두사 (예: petclinic-dev)"
  type        = string
}

variable "environment" {
  description = "환경 레이블 (예: dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS 리전"
  type        = string
}

variable "backend_bucket" {
  description = "Terraform 백엔드 S3 버킷 이름"
  type        = string
}

variable "tags" {
  description = "리소스에 적용할 공통 태그"
  type        = map(string)
  default     = {}
}

# S3 설정
variable "enable_versioning" {
  description = "S3 버킷 버저닝 활성화 여부"
  type        = bool
  default     = true
}

variable "enable_access_logging" {
  description = "S3 액세스 로깅 활성화 여부"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch 로그 보관 기간 (일)"
  type        = number
  default     = 30
}

variable "enable_cors" {
  description = "S3 버킷 CORS 활성화 여부"
  type        = bool
  default     = true
}

# CloudFront 설정
variable "price_class" {
  description = "CloudFront 가격 등급"
  type        = string
  default     = "PriceClass_100"
  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.price_class)
    error_message = "가격 등급은 PriceClass_All, PriceClass_200, PriceClass_100 중 하나여야 합니다."
  }
}

variable "enable_spa_routing" {
  description = "SPA 라우팅 활성화 여부"
  type        = bool
  default     = true
}

variable "enable_cors_headers" {
  description = "CORS 헤더 추가 활성화 여부"
  type        = bool
  default     = true
}

# SSL/TLS 설정
variable "use_default_certificate" {
  description = "CloudFront 기본 인증서 사용 여부"
  type        = bool
  default     = true
}

variable "acm_certificate_arn" {
  description = "ACM 인증서 ARN (사용자 지정 도메인용)"
  type        = string
  default     = null
}

# 로깅 설정
variable "enable_cloudfront_logging" {
  description = "CloudFront 액세스 로깅 활성화 여부"
  type        = bool
  default     = true
}

variable "log_bucket_domain_name" {
  description = "로그를 저장할 S3 버킷 도메인 이름"
  type        = string
  default     = null
}

variable "log_prefix" {
  description = "로그 파일 접두사"
  type        = string
  default     = "cloudfront/"
}

# 보안 설정
variable "web_acl_arn" {
  description = "WAF Web ACL ARN"
  type        = string
  default     = null
}

# 모니터링 설정
variable "enable_monitoring" {
  description = "CloudWatch 알람 활성화 여부"
  type        = bool
  default     = true
}

variable "error_4xx_threshold" {
  description = "4XX 에러 알람 임계값 (%)"
  type        = number
  default     = 5
}

variable "error_5xx_threshold" {
  description = "5XX 에러 알람 임계값 (%)"
  type        = number
  default     = 2
}

variable "alarm_actions" {
  description = "알람 발생 시 실행할 액션 (SNS 토픽 ARN 등)"
  type        = list(string)
  default     = []
}