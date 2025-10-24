variable "vpc_id" {
  description = "Private DNS 네임스페이스가 생성될 vpc의 ID"
  type = string
}

variable "namespace_name" {
  description = "서비스 디스커버리용 Private DNS 네임스페이스 이름(ex: petclinic.local)"
  type = string
  default = "" # 네임스페이스 이름 기본값
}

variable "service_name_map" {
  description = "네임스페이스 안에 생성할 서비스들의 맵"
                #Key = 서비스 이름 / value = 서비스의 설명
  type = map(string)
  default = {}
}