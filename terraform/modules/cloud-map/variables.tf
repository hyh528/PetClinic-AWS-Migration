# Cloud Map 모듈 변수 정의

variable "name_prefix" {
  description = "리소스 이름 접두사 (예: petclinic-dev)"
  type        = string
}

variable "environment" {
  description = "환경 레이블 (예: dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "서비스 디스커버리를 생성할 VPC ID"
  type        = string
}

# 네임스페이스 설정
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

# 마이크로서비스 목록
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
  
  validation {
    condition     = contains(["A", "AAAA", "CNAME", "SRV"], var.dns_record_type)
    error_message = "DNS 레코드 타입은 A, AAAA, CNAME, SRV 중 하나여야 합니다."
  }
}

variable "routing_policy" {
  description = "라우팅 정책"
  type        = string
  default     = "MULTIVALUE"
  
  validation {
    condition     = contains(["MULTIVALUE", "WEIGHTED"], var.routing_policy)
    error_message = "라우팅 정책은 MULTIVALUE 또는 WEIGHTED여야 합니다."
  }
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

# 태그
variable "tags" {
  description = "리소스에 적용할 공통 태그"
  type        = map(string)
  default     = {}
}

# 고급 설정
variable "force_destroy" {
  description = "네임스페이스 강제 삭제 허용 여부"
  type        = bool
  default     = false
}