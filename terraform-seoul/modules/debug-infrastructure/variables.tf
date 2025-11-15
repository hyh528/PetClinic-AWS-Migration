# =============================================================================
# Bastion Host Module - Variables
# =============================================================================

variable "enable_debug_infrastructure" {
  description = "Bastion Host 생성 여부 (개발 환경에서만 true)"
  type        = bool
  default     = false
}

variable "name_prefix" {
  description = "리소스 이름 접두사"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "퍼블릭 서브넷 ID 목록 (Bastion Host용)"
  type        = list(string)
}



variable "aurora_security_group_id" {
  description = "Aurora 보안 그룹 ID"
  type        = string
}

variable "key_pair_name" {
  description = "EC2 키 페어 이름"
  type        = string
  default     = "petclinic-debug"
}

variable "bastion_instance_type" {
  description = "Bastion Host 인스턴스 타입"
  type        = string
  default     = "t3.micro"
}



variable "bastion_allowed_cidrs" {
  description = "Bastion Host SSH 접근 허용 CIDR 목록"
  type        = list(string)
  default     = ["0.0.0.0/0"] # 프로덕션에서는 제한된 IP만 허용
}

variable "aws_region" {
  description = "AWS 리전"
  type        = string
}

variable "db_cluster_endpoint" {
  description = "Aurora 클러스터 엔드포인트"
  type        = string
}

variable "rds_secret_access_policy_arn" {
  description = "RDS Secrets Manager 접근 정책 ARN"
  type        = string
}

variable "parameter_store_access_policy_arn" {
  description = "Parameter Store 접근 정책 ARN"
  type        = string
}

variable "tags" {
  description = "리소스에 적용할 공통 태그"
  type        = map(string)
  default     = {}
}