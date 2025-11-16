# =============================================================================
# Notification Module Variables
# =============================================================================

variable "name_prefix" {
  description = "리소스 이름 접두사"
  type        = string
}

variable "environment" {
  description = "환경 레이블 (dev, staging, prod)"
  type        = string
}

variable "tags" {
  description = "리소스에 적용할 공통 태그"
  type        = map(string)
  default     = {}
}

# =============================================================================
# Slack 설정
# =============================================================================

variable "slack_webhook_url" {
  description = "Slack Incoming Webhook URL"
  type        = string
  sensitive   = true
}

variable "slack_channel" {
  description = "Slack 채널 이름 (예: #alerts, #devops)"
  type        = string
  default     = "#alerts"
}

# =============================================================================
# 이메일 알림 설정
# =============================================================================

variable "email_endpoint" {
  description = "이메일 알림을 받을 이메일 주소 (선택사항)"
  type        = string
  default     = ""
}

# =============================================================================
# Lambda 설정
# =============================================================================

variable "log_retention_days" {
  description = "Lambda 함수 로그 보관 기간 (일)"
  type        = number
  default     = 14
}

# =============================================================================
# 테스트 설정
# =============================================================================

variable "create_test_alarm" {
  description = "알림 시스템 테스트용 알람 생성 여부"
  type        = bool
  default     = false
}