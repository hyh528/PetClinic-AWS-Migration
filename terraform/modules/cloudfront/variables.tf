# CloudFront Distribution Module Variables

variable "name_prefix" {
  description = "리소스 이름 접두사 (예: petclinic-dev)"
  type        = string
}

variable "environment" {
  description = "환경 레이블 (예: dev, staging, prod)"
  type        = string
}

variable "tags" {
  description = "리소스에 적용할 공통 태그"
  type        = map(string)
  default     = {}
}

# S3 버킷 설정
variable "s3_bucket_name" {
  description = "프론트엔드 파일을 호스팅하는 S3 버킷 이름"
  type        = string
}

variable "s3_bucket_regional_domain_name" {
  description = "S3 버킷 리전 도메인 이름"
  type        = string
}

variable "cloudfront_oai_path" {
  description = "CloudFront Origin Access Identity 경로"
  type        = string
}

# API Gateway 통합 설정
variable "enable_api_gateway_integration" {
  description = "API Gateway 통합 활성화 여부"
  type        = bool
  default     = true
}

variable "api_gateway_domain_name" {
  description = "API Gateway 도메인 이름"
  type        = string
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

# SPA 라우팅 설정
variable "enable_spa_routing" {
  description = "SPA 라우팅 활성화 여부 (CloudFront 함수 사용)"
  type        = bool
  default     = true
}

# CORS 헤더 설정
variable "enable_cors_headers" {
  description = "CORS 헤더 추가 활성화 여부 (Lambda@Edge 사용)"
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

variable "ssl_support_method" {
  description = "SSL 지원 방법"
  type        = string
  default     = "sni-only"
  validation {
    condition     = contains(["sni-only", "vip"], var.ssl_support_method)
    error_message = "SSL 지원 방법은 sni-only 또는 vip여야 합니다."
  }
}

variable "minimum_protocol_version" {
  description = "최소 TLS 프로토콜 버전"
  type        = string
  default     = "TLSv1.2_2021"
  validation {
    condition = contains([
      "SSLv3", "TLSv1", "TLSv1_2016", "TLSv1.1_2016", "TLSv1.2_2018", "TLSv1.2_2019", "TLSv1.2_2021"
    ], var.minimum_protocol_version)
    error_message = "유효하지 않은 TLS 프로토콜 버전입니다."
  }
}

# 지리적 제한 설정
variable "geo_restriction_type" {
  description = "지리적 제한 타입"
  type        = string
  default     = "none"
  validation {
    condition     = contains(["none", "whitelist", "blacklist"], var.geo_restriction_type)
    error_message = "지리적 제한 타입은 none, whitelist, blacklist 중 하나여야 합니다."
  }
}

variable "geo_restriction_locations" {
  description = "지리적 제한 국가 코드 목록"
  type        = list(string)
  default     = []
}

# 로깅 설정
variable "enable_logging" {
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

# WAF 설정
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