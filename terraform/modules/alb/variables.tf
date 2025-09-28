variable "name_prefix" {
  description = "리소스 이름 접두사, 예: petclinic-dev"
  type        = string
}

variable "environment" {
  description = "환경 레이블, 예: dev|stg|prd"
  type        = string
}

variable "vpc_id" {
  description = "ALB가 배치될 VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "ALB용 퍼블릭 서브넷 ID 목록 (AZ 전체)"
  type        = list(string)
}

variable "certificate_arn" {
  description = "HTTPS 리스너용 ACM 인증서 ARN (ap-northeast-2). HTTP 전용으로 실행하려면 비워두세요."
  type        = string
  default     = ""
}

variable "target_port" {
  description = "기본 대상 그룹 포트 (예: 8080)"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "기본 대상 그룹의 헬스 체크 경로"
  type        = string
  default     = "/actuator/health"
}

variable "create_http_redirect" {
  description = "HTTPS (443)로 리디렉션하는 HTTP (80) 리스너 생성"
  type        = bool
  default     = true
}

variable "allow_ingress_cidrs_ipv4" {
  description = "80/443에서 ALB에 액세스할 수 있는 IPv4 CIDR"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allow_ingress_ipv6_any" {
  description = "80/443에서 IPv6 ::/0 허용 (듀얼스택)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "공통 리소스 태그"
  type        = map(string)
  default     = {}
}