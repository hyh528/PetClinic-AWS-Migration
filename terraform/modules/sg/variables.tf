# 보안 그룹 모듈에서 사용될 변수들을 정의합니다.

# 생성할 보안 그룹의 종류를 결정하는 변수 (예: alb, app, db, vpce)
variable "sg_type" {
  description = "생성할 보안 그룹의 종류를 지정합니다 (예: alb, app, db, vpce)."
  type        = string
}

# 보안 그룹 이름에 사용될 접두사 변수 (예: petclinic-dev)
variable "name_prefix" {
  description = "보안 그룹 이름에 사용할 접두사입니다 (예: petclinic-dev)."
  type        = string
}

# 보안 그룹이 속할 VPC의 ID 변수
variable "vpc_id" {
  description = "보안 그룹이 생성될 VPC의 ID입니다."
  type        = string
}

# DB 보안 그룹에 접근을 허용할 App 보안 그룹의 ID 변수
# 이 변수는 sg_type이 "db"일 때만 사용됩니다.
variable "app_source_security_group_id" {
  description = "DB에 접근을 허용할 App 보안 그룹의 ID입니다."
  type        = string
  default     = null
}

# App 보안 그룹에 접근을 허용할 ALB 보안 그룹의 ID 변수
# 이 변수는 sg_type이 "app"일 때만 사용됩니다.
variable "alb_source_security_group_id" {
  description = "App에 접근을 허용할 ALB 보안 그룹의 ID입니다."
  type        = string
  default     = null
}

# 리소스에 추가될 공통 태그를 위한 변수
variable "tags" {
  description = "리소스에 추가할 태그 맵입니다."
  type        = map(string)
  default     = {}
}

# VPC CIDR 변수
variable "vpc_cidr" {
  description = "VPC의 CIDR 블록입니다."
  type        = string
}
