variable "project_name" {
  description = "The name of the project, used for naming resources."
  type        = string
  default     = "petclinic"
}

variable "team_members" {
  description = "A list of team member names to create IAM users for."
  type        = list(string)
  default     = []
}

# DB 비밀번호 Secret ARN (ECS Task Role 정책에 사용)
variable "db_secret_arn" {
  description = "ECS Task Role에 연결될 DB 비밀번호 Secret의 ARN입니다."
  type        = string
  default     = null
}

# DB 비밀번호 암호화에 사용된 KMS 키의 ARN (ECS Task Role 정책에 사용)
variable "db_secret_kms_key_arn" {
  description = "DB 비밀번호 암호화에 사용된 KMS 키의 ARN입니다."
  type        = string
  default     = null
}
