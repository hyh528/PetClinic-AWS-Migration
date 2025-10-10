# =============================================================================
# Production 환경 변수
# =============================================================================

# 환경 설정
environment = "prod"

# AWS 설정
aws_region  = "ap-northeast-1"
aws_profile = "petclinic-prod"

# Terraform 상태 관리
tfstate_bucket_name = "petclinic-yeonghyeon-test"

# 네트워킹 설정 (Production은 더 큰 CIDR 사용)
name_prefix = "petclinic-prod"
vpc_cidr    = "10.2.0.0/16"

azs = [
  "ap-northeast-1a",
  "ap-northeast-1c",
  "ap-northeast-1d"  # Production은 3개 AZ 사용
]

public_subnet_cidrs      = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
private_app_subnet_cidrs = ["10.2.4.0/24", "10.2.5.0/24", "10.2.6.0/24"]
private_db_subnet_cidrs  = ["10.2.7.0/24", "10.2.8.0/24", "10.2.9.0/24"]

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
  Environment = "prod"
  ManagedBy   = "terraform"
  Owner       = "team-petclinic"
  CostCenter  = "production"
}