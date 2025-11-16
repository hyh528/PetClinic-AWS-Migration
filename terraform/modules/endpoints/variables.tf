variable "name_prefix" {
  description = "리소스 이름 접두사, 예: petclinic-dev"
  type        = string
}

variable "environment" {
  description = "환경 레이블, 예: dev|stg|prd"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "인터페이스 엔드포인트 SG 인그레스를 범위 지정하는 데 사용되는 VPC IPv4 CIDR"
  type        = string
}

variable "interface_subnet_ids" {
  description = "인터페이스 엔드포인트를 배치할 서브넷 (일반적으로 프라이빗 앱 서브넷)"
  type        = list(string)
}

variable "public_route_table_id" {
  description = "S3 게이트웨이 엔드포인트 연결용 퍼블릭 라우트 테이블 ID (선택 사항)"
  type        = string
}

variable "private_app_route_table_ids" {
  description = "S3 게이트웨이 엔드포인트 연결용 프라이빗 앱 라우트 테이블 ID 맵"
  type        = map(string)
  default     = {}
}

variable "private_db_route_table_ids" {
  description = "S3 게이트웨이 엔드포인트 연결용 프라이빗 DB 라우트 테이블 ID 맵"
  type        = map(string)
  default     = {}
}

variable "create_interface_endpoints" {
  description = "인터페이스 엔드포인트를 생성할지 여부"
  type        = bool
  default     = true
}

variable "interface_services" {
  description = "인터페이스 엔드포인트 짧은 서비스 이름 목록 (예: [\"ecr.api\",\"ecr.dkr\",\"logs\",\"xray\",\"ssm\",\"ssmmessages\",\"ec2messages\",\"secretsmanager\",\"kms\"])"
  type        = list(string)
  default     = ["ecr.api", "ecr.dkr", "logs", "xray", "ssm", "ssmmessages", "ec2messages", "secretsmanager", "kms"]
}

variable "tags" {
  description = "공통 리소스 태그"
  type        = map(string)
  default     = {}
}