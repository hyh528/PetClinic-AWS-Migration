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

variable "tfstate_bucket_name" {
  description = "Terraform 상태 파일을 저장할 S3 버킷 이름"
  type        = string
}

# =============================================================================
# ECS 관련 변수
# =============================================================================

variable "service_image_map" {
  description = "서비스별 Docker 이미지 매핑 (CI에서 빌드된 이미지 태그 사용)"
  type        = map(string)
  default     = {}
}

# =============================================================================
# 디버깅 인프라 관련 변수
# =============================================================================

variable "enable_debug_infrastructure" {
  description = "디버깅 인프라 생성 여부 (개발 환경에서만 true)"
  type        = bool
  default     = false
}

# =============================================================================
# ALB Rate Limiting 및 보안 설정
# =============================================================================

variable "enable_alb_rate_limiting" {
  description = "ALB WAF Rate Limiting 활성화 여부"
  type        = bool
  default     = true
}

variable "alb_rate_limit_per_ip" {
  description = "ALB - IP당 5분간 요청 제한 수"
  type        = number
  default     = 1000
}

variable "alb_rate_limit_burst_per_ip" {
  description = "ALB - IP당 1분간 버스트 요청 제한 수"
  type        = number
  default     = 200
}

variable "enable_geo_blocking" {
  description = "지역 차단 기능 활성화 여부"
  type        = bool
  default     = false
}

variable "blocked_countries" {
  description = "차단할 국가 코드 목록 (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = []
}

variable "enable_security_rules" {
  description = "추가 보안 규칙 활성화 여부 (SQL Injection, XSS 방지)"
  type        = bool
  default     = true
}

variable "enable_waf_monitoring" {
  description = "WAF 모니터링 및 알람 활성화 여부"
  type        = bool
  default     = true
}

variable "alb_rate_limit_alarm_threshold" {
  description = "ALB Rate Limiting 위반 알람 임계값 (5분간 차단된 요청 수)"
  type        = number
  default     = 100
}

variable "alarm_actions" {
  description = "알람 발생 시 실행할 액션 (SNS 토픽 ARN 등)"
  type        = list(string)
  default     = []
}

# =============================================================================
# 모니터링 관련 변수
# =============================================================================

variable "enable_ecs_monitoring" {
  description = "ECS 서비스 모니터링 및 알람 활성화 여부"
  type        = bool
  default     = true
}

variable "cpu_alarm_threshold" {
  description = "ECS CPU 사용률 알람 임계값 (%)"
  type        = number
  default     = 80

  validation {
    condition     = var.cpu_alarm_threshold > 0 && var.cpu_alarm_threshold <= 100
    error_message = "CPU 알람 임계값은 0과 100 사이여야 합니다."
  }
}

variable "memory_alarm_threshold" {
  description = "ECS 메모리 사용률 알람 임계값 (%)"
  type        = number
  default     = 85

  validation {
    condition     = var.memory_alarm_threshold > 0 && var.memory_alarm_threshold <= 100
    error_message = "메모리 알람 임계값은 0과 100 사이여야 합니다."
  }
}

variable "response_time_threshold" {
  description = "ALB 응답 시간 알람 임계값 (초)"
  type        = number
  default     = 5

  validation {
    condition     = var.response_time_threshold > 0
    error_message = "응답 시간 임계값은 0보다 커야 합니다."
  }
}

variable "error_5xx_threshold" {
  description = "ALB 5XX 에러 알람 임계값 (5분간 에러 수)"
  type        = number
  default     = 10

  validation {
    condition     = var.error_5xx_threshold >= 0
    error_message = "5XX 에러 임계값은 0 이상이어야 합니다."
  }
}