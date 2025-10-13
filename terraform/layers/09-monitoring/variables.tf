# =============================================================================
# Monitoring Layer Variables
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

# =============================================================================
# Monitoring Layer 전용 변수
# =============================================================================

variable "alert_email" {
  description = "알람 알림을 받을 이메일 주소"
  type        = string
  default     = "admin@petclinic.local"
}

variable "sns_topic_arn" {
  description = "알람 알림용 SNS 토픽 ARN"
  type        = string
  default     = ""
}