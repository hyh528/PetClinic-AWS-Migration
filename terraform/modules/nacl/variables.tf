# NACL 모듈에서 사용될 변수들을 정의합니다.

# NACL이 연결될 VPC의 ID 변수
variable "vpc_id" {
  description = "NACL이 연결될 VPC의 ID입니다."
  type        = string
}

# NACL 규칙에서 사용할 VPC의 CIDR 블록 변수
variable "vpc_cidr" {
  description = "NACL 규칙에서 사용할 VPC의 CIDR 블록입니다."
  type        = string
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