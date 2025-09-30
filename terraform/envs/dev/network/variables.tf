# 네트워크 레이어 변수

variable "name_prefix" {
  description = "리소스 이름 접두사, 예: petclinic-dev"
  type        = string
  default     = "petclinic-dev"
}

variable "environment" {
  description = "환경 레이블, 예: dev|stg|prd"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "VPC IPv4 CIDR 블록"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_ipv6" {
  description = "VPC 및 서브넷에 IPv6 (듀얼스택) 활성화"
  type        = bool
  default     = true
}

variable "azs" {
  description = "서브넷 CIDR과 일치하는 가용 영역"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "public_subnet_cidrs" {
  description = "퍼블릭 서브넷 IPv4 CIDR (AZ당 하나)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "프라이빗 앱 서브넷 IPv4 CIDR (AZ당 하나)"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "private_db_subnet_cidrs" {
  description = "프라이빗 DB 서브넷 IPv4 CIDR (AZ당 하나)"
  type        = list(string)
  default     = ["10.0.5.0/24", "10.0.6.0/24"]
}

variable "create_nat_per_az" {
  description = "HA를 위해 AZ당 하나의 NAT 게이트웨이 생성 (비용 더 많이 듦)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "모든 리소스에 병합되는 추가 태그 (provider default_tags도 적용됨)"
  type        = map(string)
  default     = {}
}
# ==========================================
# Network 환경 공통 변수 선언 (백엔드/프로바이더)
# ==========================================
# - backend "s3" 및 provider "aws"에서 참조하는 공통 값
# - 값은 terraform/backend.tfvars 또는 -var-file/-var로 주입
# - 프로파일은 기본값을 제공하되 필요 시 override 가능

# 원격 상태(S3) 버킷 이름
variable "tfstate_bucket_name" {
  description = "Terraform 원격 상태 보관용 S3 버킷 이름"
  type        = string
}

# 상태 잠금(DynamoDB) 테이블 이름
variable "tf_lock_table_name" {
  description = "Terraform 상태 잠금을 위한 DynamoDB 테이블 이름"
  type        = string
}

# 리전
variable "aws_region" {
  description = "리소스를 배포할 AWS 리전 (예: ap-northeast-2)"
  type        = string
}

# 상태 암호화 사용 여부
variable "encrypt_state" {
  description = "원격 상태 암호화 사용 여부"
  type        = bool
}

# 이 환경에서 리소스를 생성/변경하는 기본 AWS CLI 프로파일
variable "aws_profile" {
  description = "Network 레이어에서 사용하는 기본 AWS CLI 프로파일"
  type        = string
}