# =============================================================================
# Development 환경 변수
# =============================================================================

# 환경 설정
environment = "dev"

# AWS 설정
aws_region  = "us-west-2"
aws_profile = "petclinic-dev"

# Terraform 상태 관리
tfstate_bucket_name = "petclinic-tfstate-oregon-dev"

# 네트워킹 설정
name_prefix = "petclinic-dev"
vpc_cidr    = "10.0.0.0/16"

azs = [
  "us-west-2a",
  "us-west-2b"
]

public_subnet_cidrs      = ["10.0.1.0/24", "10.0.2.0/24"]
private_app_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
private_db_subnet_cidrs  = ["10.0.5.0/24", "10.0.6.0/24"]

# NAT Gateway 설정 (ECR pull 등 인터넷 액세스 필요)
single_nat_gateway = false
create_nat_per_az  = true

# VPC 엔드포인트 서비스 (security 레이어에서 사용)
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

# =============================================================================
# Security Layer 설정
# =============================================================================

# Cross-Layer 통합 설정
enable_alb_integration = true # Phase 1: false, Phase 2 (application 레이어 배포 후): true

# IAM 설정
team_members               = ["yeonghyeon", "seokgyeom", "junje", "hwigwon"]
enable_role_based_policies = false # Phase 1: false (모든 멤버 Admin), Phase 2: true (역할별 권한)

# 보안 기능 설정
enable_vpc_flow_logs = true
enable_cloudtrail    = true

# =============================================================================
# Database Layer 설정
# =============================================================================

# Aurora 클러스터 설정
instance_class = "db.serverless" # Aurora Serverless v2
engine_version = "8.0.mysql_aurora.3.04.0"

# 데이터베이스 설정
db_name     = "petclinic"
db_username = "petclinic"
db_port     = 3306

# 백업 및 유지보수 설정
backup_retention_period = 7
backup_window           = "03:00-04:00"         # UTC (한국시간 12:00-13:00)
maintenance_window      = "sun:04:00-sun:05:00" # UTC (한국시간 일요일 13:00-14:00)

# 보안 설정
storage_encrypted = true

# 성능 모니터링 설정
performance_insights_enabled = true
monitoring_interval          = 60

# 공통 태그
tags = {
  Project     = "petclinic"
  Environment = "dev"
  ManagedBy   = "terraform"
  Owner       = "team-petclinic"
  CostCenter  = "training"
}

# =============================================================================
# 공유 설정 (레이어 간 공통 사용)
# =============================================================================

shared_config = {
  name_prefix = "petclinic-dev"
  environment = "dev"
  aws_region  = "us-west-2"
  aws_profile = "petclinic-dev"
  common_name = "petclinic-dev"
  common_tags = {
    Project     = "petclinic"
    Environment = "dev"
    ManagedBy   = "terraform"
    Owner       = "team-petclinic"
    CostCenter  = "training"
  }
}

network_config = {
  vpc_cidr                 = "10.0.0.0/16"
  azs                      = ["us-west-2a", "us-west-2b"]
  public_subnet_cidrs      = ["10.0.1.0/24", "10.0.2.0/24"]
  private_app_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
  private_db_subnet_cidrs  = ["10.0.5.0/24", "10.0.6.0/24"]
}

state_config = {
  bucket_name = "petclinic-tfstate-oregon-dev"
  region      = "us-west-2"
  profile     = "petclinic-dev"
}
