variable "name_prefix" {
  description = "리소스 이름 접두사, 예: petclinic-dev"
  type        = string
}

variable "environment" {
  description = "환경 레이블, 예: dev|stg|prd"
  type        = string
}

variable "vpc_id" {
  description = "ALB가 배치될 VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "ALB용 퍼블릭 서브넷 ID 목록 (AZ 전체)"
  type        = list(string)
}

variable "certificate_arn" {
  description = "HTTPS 리스너용 ACM 인증서 ARN (ap-northeast-2). HTTP 전용으로 실행하려면 비워두세요."
  type        = string
  default     = ""
}

variable "target_port" {
  description = "기본 대상 그룹 포트 (예: 8080)"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "기본 대상 그룹의 헬스 체크 경로"
  type        = string
  default     = "/actuator/health"
}

variable "create_http_redirect" {
  description = "HTTPS (443)로 리디렉션하는 HTTP (80) 리스너 생성"
  type        = bool
  default     = true
}

variable "allow_ingress_cidrs_ipv4" {
  description = "80/443에서 ALB에 액세스할 수 있는 IPv4 CIDR"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allow_ingress_ipv6_any" {
  description = "80/443에서 IPv6 ::/0 허용 (듀얼스택)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "공통 리소스 태그"
  type        = map(string)
  default     = {}
}

# Rate Limiting 설정
variable "enable_waf_rate_limiting" {
  description = "ALB에 WAF Rate Limiting 활성화 여부"
  type        = bool
  default     = true
}

variable "rate_limit_per_ip" {
  description = "IP당 5분간 요청 제한 수"
  type        = number
  default     = 1000

  validation {
    condition     = var.rate_limit_per_ip > 0 && var.rate_limit_per_ip <= 20000
    error_message = "IP당 요청 제한은 1에서 20000 사이여야 합니다."
  }
}

variable "rate_limit_burst_per_ip" {
  description = "IP당 1분간 버스트 요청 제한 수"
  type        = number
  default     = 200

  validation {
    condition     = var.rate_limit_burst_per_ip > 0 && var.rate_limit_burst_per_ip <= 5000
    error_message = "IP당 버스트 요청 제한은 1에서 5000 사이여야 합니다."
  }
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

  validation {
    condition = alltrue([
      for country in var.blocked_countries :
      length(country) == 2
    ])
    error_message = "국가 코드는 2자리 ISO 3166-1 alpha-2 형식이어야 합니다."
  }
}

variable "enable_security_rules" {
  description = "추가 보안 규칙 활성화 여부 (SQL Injection, XSS 방지)"
  type        = bool
  default     = true
}

variable "waf_log_retention_days" {
  description = "WAF 로그 보관 기간 (일)"
  type        = number
  default     = 14
}

variable "enable_waf_monitoring" {
  description = "WAF 모니터링 및 알람 활성화 여부"
  type        = bool
  default     = true
}

variable "rate_limit_alarm_threshold" {
  description = "Rate Limiting 위반 알람 임계값 (5분간 차단된 요청 수)"
  type        = number
  default     = 100
}

variable "alarm_actions" {
  description = "알람 발생 시 실행할 액션 (SNS 토픽 ARN 등)"
  type        = list(string)
  default     = []
}