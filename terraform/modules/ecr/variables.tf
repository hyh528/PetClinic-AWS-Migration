variable "repository_names" {
  description =  "ECR 리포지토리 이름들"
  type = list(string)
  default = []      # 마이크로서비스 이름
}

variable "tags" {
    description = ""
    type = map(string)
    default = {}
}