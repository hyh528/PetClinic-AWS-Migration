# NACL 모듈에서 사용될 변수들을 정의합니다.

# NACL이 연결될 VPC의 ID 변수
variable "vpc_id" {
  description = "NACL이 연결될 VPC의 ID입니다."
  type        = string
}

# NACL 규칙에서 사용할 VPC의 CIDR 블록 변수 (IPv4)
variable "vpc_cidr" {
  description = "NACL 규칙에서 사용할 VPC의 IPv4 CIDR 블록입니다."
  type        = string
}

# NACL 규칙에서 사용할 VPC의 IPv6 CIDR 블록 변수 (선택사항)
variable "vpc_ipv6_cidr" {
  description = "NACL 규칙에서 사용할 VPC의 IPv6 CIDR 블록입니다 (선택사항)."
  type        = string
  default     = null
}

# NACL이 연결될 서브넷 ID 목록 변수
variable "subnet_ids" {
  description = "NACL과 연결될 서브넷 ID 목록입니다."
  type        = list(string)
}

# 생성될 NACL 리소스의 이름에 사용될 접두사 변수 (예: public, private-app)
variable "name_prefix" {
  description = "NACL 리소스 이름에 사용될 접두사입니다 (예: public, private-app)."
  type        = string
}

# 리소스 태그에 사용될 환경 정보 변수 (예: dev, prod)
variable "environment" {
  description = "NACL 리소스에 태그로 지정될 환경입니다 (예: dev, prod)."
  type        = string
}

# 생성할 NACL의 타입 변수 (예: public, private-app, private-db)
variable "nacl_type" {
  description = "생성할 NACL의 타입입니다 (예: public, private-app, private-db)."
  type        = string
  validation {
    condition     = contains(["public", "private-app", "private-db"], var.nacl_type)
    error_message = "nacl_type은 'public', 'private-app', 'private-db' 중 하나여야 합니다."
  }
}

# 모니터링 및 로깅 변수 추가
variable "enable_flow_logs" {
  description = "NACL 모니터링을 위한 VPC Flow Logs를 활성화할지 여부입니다."
  type        = bool
  default     = false
}

variable "flow_logs_role_arn" {
  description = "VPC Flow Logs를 위한 IAM 역할의 ARN입니다."
  type        = string
  default     = null
}

variable "flow_logs_log_group_arn" {
  description = "VPC Flow Logs를 위한 CloudWatch Logs 그룹의 ARN입니다."
  type        = string
  default     = null
}

variable "flow_logs_log_group_name" {
  description = "VPC Flow Logs를 위한 CloudWatch Logs 그룹의 이름입니다."
  type        = string
  default     = null
}

variable "enable_security_monitoring" {
  description = "NACL 거부에 대한 보안 모니터링 및 알람을 활성화할지 여부입니다."
  type        = bool
  default     = false
}

variable "security_alert_threshold" {
  description = "NACL 거부 연결 알람의 임계값입니다."
  type        = number
  default     = 100
}

variable "alarm_actions" {
  description = "보안 알람 발생 시 알림을 받을 SNS 토픽 ARN 목록입니다."
  type        = list(string)
  default     = []
}