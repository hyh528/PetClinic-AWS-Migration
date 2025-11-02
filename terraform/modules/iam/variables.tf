variable "project_name" {
  description = "리소스용 프로젝트 이름 접두사"
  type        = string
  default     = "petclinic"
}

variable "team_members" {
  description = "팀 멤버 이름 목록"
  type        = list(string)
  default = [
    "yeonghyeon",
    "seokgyeom",
    "junje",
    "hwigwon"
  ]
}

variable "enable_role_based_policies" {
  description = "AdministratorAccess 대신 역할 기반 정책 활성화"
  type        = bool
  default     = false
}

variable "tags" {
  description = "공통 리소스 태그"
  type        = map(string)
  default     = {}
}
