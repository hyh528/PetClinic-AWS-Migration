variable "trail_name" {
  description = "CloudTrail 트레일의 이름입니다."
  type        = string
}

variable "s3_bucket_name" {
  description = "CloudTrail 로그를 저장할 S3 버킷의 이름입니다."
  type        = string
}

variable "enable_logging" {
  description = "CloudTrail 로깅을 활성화할지 여부입니다."
  type        = bool
  default     = true
}

variable "is_multi_region_trail" {
  description = "모든 리전의 이벤트를 기록할지 여부입니다."
  type        = bool
  default     = true
}

variable "enable_log_file_validation" {
  description = "로그 파일 무결성 검증을 활성화할지 여부입니다."
  type        = bool
  default     = true
}

variable "include_global_service_events" {
  description = "IAM, CloudFront와 같은 글로벌 서비스 이벤트를 포함할지 여부입니다."
  type        = bool
  default     = true
}

variable "cloud_watch_logs_group_arn" {
  description = "CloudTrail 이벤트를 전송할 CloudWatch Logs 그룹의 ARN입니다."
  type        = string
  default     = null
}

variable "cloud_watch_logs_role_arn" {
  description = "CloudTrail이 CloudWatch Logs에 이벤트를 전송하기 위해 사용할 IAM 역할의 ARN입니다."
  type        = string
  default     = null
}

variable "tags" {
  description = "리소스에 적용할 공통 태그입니다."
  type        = map(string)
  default     = {}
}