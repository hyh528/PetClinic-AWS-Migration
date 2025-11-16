# Cloud Map 모듈 변수 정의 - 단순화됨

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

# 네임스페이스 설정 (기본값 사용)
variable "namespace_name" {
  description = "프라이빗 DNS 네임스페이스 이름"
  type        = string
  default     = "petclinic.local"
}

# 마이크로서비스 목록 (ECS 서비스만)
variable "microservices" {
  description = "서비스 디스커버리에 등록할 마이크로서비스 목록"
  type        = list(string)
  default     = ["customers", "vets", "visits", "admin"]
}

# DNS 설정 (기본값만)
variable "dns_ttl" {
  description = "DNS 레코드 TTL (초)"
  type        = number
  default     = 60
}

# 태그
variable "tags" {
  description = "리소스에 적용할 공통 태그"
  type        = map(string)
  default     = {}
}