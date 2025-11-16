# =============================================================================
# Staging 환경 변수
# =============================================================================

# 환경 설정
environment = "staging"

# AWS 설정
aws_region  = "ap-northeast-1"
aws_profile = "petclinic-staging"

# Terraform 상태 관리
tfstate_bucket_name = "petclinic-yeonghyeon-test"

# 네트워킹 설정 (Staging은 더 작은 CIDR 사용)
name_prefix = "petclinic-staging"
vpc_cidr    = "10.1.0.0/16"

azs = [
  "ap-northeast-1a",
  "ap-northeast-1c"
]

public_subnet_cidrs      = ["10.1.1.0/24", "10.1.2.0/24"]
private_app_subnet_cidrs = ["10.1.3.0/24", "10.1.4.0/24"]
private_db_subnet_cidrs  = ["10.1.5.0/24", "10.1.6.0/24"]

# VPC 엔드포인트 서비스
vpc_endpoint_services = [
  "ecr.api",
  "ecr.dkr",
  "logs",
  "xray",
  "ssm",
  "ssmmessages",
  "ec2messages",
  "secretsmanager",
  "kms",
  "monitoring"
]

# 공통 태그
tags = {
  Project     = "petclinic"
  Environment = "staging"
  ManagedBy   = "terraform"
  Owner       = "team-petclinic"
  CostCenter  = "training"
}