# ==========================================
# CloudTrail 모듈 변수 정의
# ==========================================

variable "cloudtrail_name" {
  description = "CloudTrail 이름"
  type        = string
  default     = "petclinic-audit-trail"
}

variable "cloudtrail_bucket_name" {
  description = "CloudTrail 로그를 저장할 S3 버킷 이름"
  type        = string
}

variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "log_retention_days" {
  description = "CloudWatch 로그 보관 기간 (일)"
  type        = number
  default     = 90
}

variable "sns_topic_arn" {
  description = "보안 알람 알림을 위한 SNS 토픽 ARN (선택사항)"
  type        = string
  default     = null
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
  default     = {}
}