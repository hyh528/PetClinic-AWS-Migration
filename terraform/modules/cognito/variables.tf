# 개선된 Cognito 모듈 변수 정의
# 추가 보안 설정 및 기능을 위한 변수들

# 기본 변수들
variable "project_name" {
  description = "태그 및 리소스 이름에 사용될 프로젝트 이름입니다."
  type        = string
}

variable "environment" {
  description = "태그 및 리소스 이름에 사용될 환경 이름입니다 (예: dev, prod)."
  type        = string
}

# 비밀번호 정책 변수들
variable "password_min_length" {
  description = "사용자 풀 비밀번호의 최소 길이입니다."
  type        = number
  default     = 8

  validation {
    condition     = var.password_min_length >= 6 && var.password_min_length <= 99
    error_message = "비밀번호 최소 길이는 6-99 사이여야 합니다."
  }
}

variable "password_require_lowercase" {
  description = "사용자 풀 비밀번호에 소문자가 포함되어야 하는지 여부입니다."
  type        = bool
  default     = true
}

variable "password_require_numbers" {
  description = "사용자 풀 비밀번호에 숫자가 포함되어야 하는지 여부입니다."
  type        = bool
  default     = true
}

variable "password_require_symbols" {
  description = "사용자 풀 비밀번호에 기호가 포함되어야 하는지 여부입니다."
  type        = bool
  default     = true
}

variable "password_require_uppercase" {
  description = "사용자 풀 비밀번호에 대문자가 포함되어야 하는지 여부입니다."
  type        = bool
  default     = true
}

# MFA 설정
variable "mfa_configuration" {
  description = "Multi-Factor Authentication 설정입니다."
  type        = string
  default     = "OPTIONAL"

  validation {
    condition     = contains(["OFF", "ON", "OPTIONAL"], var.mfa_configuration)
    error_message = "MFA 설정은 OFF, ON, OPTIONAL 중 하나여야 합니다."
  }
}

# 고급 보안 모드
variable "advanced_security_mode" {
  description = "고급 보안 모드 설정입니다."
  type        = string
  default     = "ENFORCED"

  validation {
    condition     = contains(["OFF", "AUDIT", "ENFORCED"], var.advanced_security_mode)
    error_message = "고급 보안 모드는 OFF, AUDIT, ENFORCED 중 하나여야 합니다."
  }
}

# 관리자 전용 사용자 생성
variable "admin_create_user_only" {
  description = "관리자만 사용자를 생성할 수 있는지 여부입니다."
  type        = bool
  default     = false
}

# OAuth 설정
variable "allowed_oauth_flows" {
  description = "허용된 OAuth 흐름 목록입니다."
  type        = list(string)
  default     = ["code", "implicit"]

  validation {
    condition = alltrue([
      for flow in var.allowed_oauth_flows : contains(["code", "implicit", "client_credentials"], flow)
    ])
    error_message = "OAuth 흐름은 code, implicit, client_credentials 중에서 선택해야 합니다."
  }
}

# 콜백 및 로그아웃 URL
variable "cognito_callback_urls" {
  description = "성공적인 로그인 후 사용자가 리다이렉트될 URL 목록입니다."
  type        = list(string)
  default     = ["http://localhost:8080/login"]

  validation {
    condition = alltrue([
      for url in var.cognito_callback_urls : can(regex("^https?://", url))
    ])
    error_message = "콜백 URL은 http:// 또는 https://로 시작해야 합니다."
  }
}

variable "cognito_logout_urls" {
  description = "로그아웃 후 사용자가 리다이렉트될 URL 목록입니다."
  type        = list(string)
  default     = ["http://localhost:8080/logout"]

  validation {
    condition = alltrue([
      for url in var.cognito_logout_urls : can(regex("^https?://", url))
    ])
    error_message = "로그아웃 URL은 http:// 또는 https://로 시작해야 합니다."
  }
}

# 토큰 유효 기간
variable "access_token_validity_minutes" {
  description = "액세스 토큰의 유효 기간 (분)입니다 (5분 ~ 1440분)."
  type        = number
  default     = 60

  validation {
    condition     = var.access_token_validity_minutes >= 5 && var.access_token_validity_minutes <= 1440
    error_message = "액세스 토큰 유효 기간은 5-1440분 사이여야 합니다."
  }
}

variable "id_token_validity_minutes" {
  description = "ID 토큰의 유효 기간 (분)입니다 (5분 ~ 1440분)."
  type        = number
  default     = 60

  validation {
    condition     = var.id_token_validity_minutes >= 5 && var.id_token_validity_minutes <= 1440
    error_message = "ID 토큰 유효 기간은 5-1440분 사이여야 합니다."
  }
}

variable "refresh_token_validity_days" {
  description = "리프레시 토큰의 유효 기간 (일)입니다 (1일 ~ 3650일)."
  type        = number
  default     = 30

  validation {
    condition     = var.refresh_token_validity_days >= 1 && var.refresh_token_validity_days <= 3650
    error_message = "리프레시 토큰 유효 기간은 1-3650일 사이여야 합니다."
  }
}

# 클라이언트 시크릿 생성
variable "generate_client_secret" {
  description = "클라이언트 시크릿을 생성할지 여부입니다 (서버 측 애플리케이션용)."
  type        = bool
  default     = true
}

# Identity Pool 생성 여부
variable "create_identity_pool" {
  description = "Cognito Identity Pool을 생성할지 여부입니다."
  type        = bool
  default     = false
}

# 커스텀 도메인 (선택사항)
variable "custom_domain" {
  description = "사용자 풀의 커스텀 도메인입니다 (선택사항)."
  type        = string
  default     = null
}

variable "certificate_arn" {
  description = "커스텀 도메인용 SSL 인증서 ARN입니다 (선택사항)."
  type        = string
  default     = null
}

# SES 설정 (선택사항)
variable "ses_source_arn" {
  description = "이메일 발송용 SES 소스 ARN입니다 (선택사항)."
  type        = string
  default     = null
}