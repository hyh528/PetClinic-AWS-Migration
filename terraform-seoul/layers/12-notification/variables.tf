# =============================================================================
# Notification Layer Variables
# =============================================================================

# =============================================================================
# 공통 변수
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
# Slack 알림 설정
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
  description = "알림 시스템 테스트용 알람 생성 여부 (개발 환경에서만 true)"
  type        = bool
  default     = false
}