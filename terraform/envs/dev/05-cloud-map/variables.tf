# Cloud Map 레이어 변수 - 단일 책임 원칙 적용

# 기본 설정
variable "name_prefix" {
  description = "리소스 이름 접두사"
  type        = string
  default     = "petclinic-dev"
}

variable "environment" {
  description = "환경 레이블"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

# Terraform 상태 관리
variable "tfstate_bucket_name" {
  description = "Terraform 상태 파일 S3 버킷 이름"
  type        = string
}

variable "network_state_profile" {
  description = "네트워크 레이어 상태 파일 접근용 AWS 프로필"
  type        = string
  default     = "petclinic-yeonghyeon"
}

# Cloud Map 전용 설정
variable "namespace_name" {
  description = "프라이빗 DNS 네임스페이스 이름"
  type        = string
  default     = "petclinic.local"
}

variable "namespace_description" {
  description = "네임스페이스 설명"
  type        = string
  default     = "PetClinic 마이크로서비스 서비스 디스커버리"
}

variable "microservices" {
  description = "서비스 디스커버리에 등록할 마이크로서비스 목록"
  type        = list(string)
  default     = ["customers", "vets", "visits", "admin"]
}

# DNS 설정
variable "dns_ttl" {
  description = "DNS 레코드 TTL (초)"
  type        = number
  default     = 60
}

variable "dns_record_type" {
  description = "DNS 레코드 타입"
  type        = string
  default     = "A"
}

variable "routing_policy" {
  description = "라우팅 정책"
  type        = string
  default     = "MULTIVALUE"
}

# 헬스체크 설정
variable "health_check_grace_period" {
  description = "헬스체크 유예 기간 (초)"
  type        = number
  default     = 30
}

variable "enable_custom_health_check" {
  description = "커스텀 헬스체크 활성화 여부"
  type        = bool
  default     = false
}

variable "health_check_failure_threshold" {
  description = "헬스체크 실패 임계값"
  type        = number
  default     = 3
}

# 모니터링 설정
variable "enable_logging" {
  description = "CloudWatch 로깅 활성화 여부"
  type        = bool
  default     = false
}

variable "enable_metrics" {
  description = "CloudWatch 메트릭 활성화 여부"
  type        = bool
  default     = false
}

variable "enable_health_alarms" {
  description = "서비스 헬스 알람 활성화 여부"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch 로그 보관 기간 (일)"
  type        = number
  default     = 30
}

variable "healthy_instance_threshold" {
  description = "정상 인스턴스 수 알람 임계값"
  type        = number
  default     = 1
}

variable "alarm_actions" {
  description = "알람 발생 시 실행할 액션 (SNS 토픽 ARN 등)"
  type        = list(string)
  default     = []
}

# 고급 설정
variable "force_destroy" {
  description = "네임스페이스 강제 삭제 허용 여부 (개발 환경용)"
  type        = bool
  default     = true
}

# 태그
variable "tags" {
  description = "모든 리소스에 적용할 공통 태그"
  type        = map(string)
  default = {
    Project     = "petclinic"
    ManagedBy   = "terraform"
    Layer       = "cloud-map"
    Owner       = "team-petclinic"
    CostCenter  = "training"
  }
}

# Provider 설정
variable "aws_profile" {
  description = "사용할 AWS CLI 프로필"
  type        = string
  default     = "petclinic-seokgyeom"
}