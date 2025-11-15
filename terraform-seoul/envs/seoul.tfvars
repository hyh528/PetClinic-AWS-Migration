# =============================================================================
# Development 환경 변수
# =============================================================================

# 환경 설정
environment = "seoul-dev"

# AWS 설정
aws_region  = "ap-northeast-2"
aws_profile = "petclinic-dev"

# Terraform 상태 관리
tfstate_bucket_name = "petclinic-tfstate-seoul-dev"
backend_bucket       = "petclinic-tfstate-seoul-dev"

# 네트워킹 설정
name_prefix = "petclinic-seoul-dev"
vpc_cidr    = "10.0.0.0/16"

azs = [
  "ap-northeast-2a",
  "ap-northeast-2c"
]

public_subnet_cidrs      = ["10.0.1.0/24", "10.0.2.0/24"]
private_app_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
private_db_subnet_cidrs  = ["10.0.5.0/24", "10.0.6.0/24"]

# NAT Gateway 설정 (ECR pull 등 인터넷 액세스 필요)
single_nat_gateway = false
create_nat_per_az  = true

# VPC 엔드포인트 서비스 (security 레이어에서 사용)
# ECR 엔드포인트 제거 - ECR DKR은 CloudFront를 통해 S3에 접근하므로 VPC 엔드포인트로는 해결되지 않음
vpc_endpoint_services = [
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
engine_version = "8.0.mysql_aurora.3.08.0"

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
  name_prefix = "petclinic-seoul-dev"
  environment = "dev"
  aws_region  = "ap-northeast-2"
  aws_profile = "petclinic-dev"
  common_name = "petclinic-seoul-dev"
  common_tags = {
    Project     = "petclinic"
    Environment = "seoul-dev"
    ManagedBy   = "terraform"
    Owner       = "team-petclinic"
    CostCenter  = "training"
  }
}

network_config = {
  vpc_cidr                 = "10.0.0.0/16"
  azs                      = ["ap-northeast-2a", "ap-northeast-2c"]
  public_subnet_cidrs      = ["10.0.1.0/24", "10.0.2.0/24"]
  private_app_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
  private_db_subnet_cidrs  = ["10.0.5.0/24", "10.0.6.0/24"]
}

state_config = {
  bucket_name = "petclinic-tfstate-seoul-dev"
  region      = "ap-northeast-2"
  profile     = "petclinic-dev"
}

# Application Layer 설정
service_image_map = {
  customers = "897722691159.dkr.ecr.ap-northeast-2.amazonaws.com/petclinic-seoul-dev-customers:latest"
  vets      = "897722691159.dkr.ecr.ap-northeast-2.amazonaws.com/petclinic-seoul-dev-vets:latest"
  visits    = "897722691159.dkr.ecr.ap-northeast-2.amazonaws.com/petclinic-seoul-dev-visits:latest"
  admin     = "897722691159.dkr.ecr.ap-northeast-2.amazonaws.com/petclinic-seoul-dev-admin:latest"
}

# Bastion Host 설정 (개발 환경에서만 활성화)
enable_debug_infrastructure = true

# =============================================================================
# Rate Limiting 및 보안 설정
# =============================================================================

# ALB Rate Limiting 설정
enable_alb_rate_limiting       = true
alb_rate_limit_per_ip          = 1000  # 5분간 1000 요청
alb_rate_limit_burst_per_ip    = 200   # 1분간 200 요청
enable_geo_blocking            = false # 개발 환경에서는 비활성화
blocked_countries              = []    # 필요시 ["CN", "RU"] 등 추가
enable_security_rules          = true  # SQL Injection, XSS 방지
enable_waf_monitoring          = true
alb_rate_limit_alarm_threshold = 100

# API Gateway Rate Limiting 설정
enable_rate_limiting         = true
rate_limit_per_ip            = 1000 # 분당 1000 요청
rate_limit_burst_per_ip      = 2000 # 버스트 2000 요청
rate_limit_window_minutes    = 1
enable_waf_integration       = true
rate_limit_alarm_threshold   = 50
enable_rate_limit_monitoring = true

# WAF Rate Limiting 규칙 (API Gateway용)
waf_rate_limit_rules = [
  {
    name        = "GeneralRateLimit"
    priority    = 1
    limit       = 1000
    window      = 300 # 5분
    action      = "BLOCK"
    description = "일반적인 Rate Limiting - 5분간 1000 요청 제한"
  },
  {
    name        = "StrictRateLimit"
    priority    = 2
    limit       = 100
    window      = 60 # 1분
    action      = "BLOCK"
    description = "엄격한 Rate Limiting - 1분간 100 요청 제한"
  }
]

# =============================================================================
# 알림 시스템 설정 (12-notification 레이어)
# =============================================================================

# Slack 알림 설정 (환경 변수 TF_VAR_slack_webhook_url 사용)
slack_webhook_url = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL" # 실제 값은 TF_VAR_slack_webhook_url 환경 변수로 설정
slack_channel     = "#petclinic-alerts"
email_endpoint    = "" # 이메일 알림 (선택사항)

# 테스트 설정 (개발 환경에서만)
create_test_alarm = true

# Bedrock 모델 설정 (서울 리전용 - Direct model ID)
bedrock_model_id = "anthropic.claude-3-haiku-20240307-v1:0"
# 알람 액션 (12-notification 레이어 배포 후 SNS 토픽 ARN으로 업데이트)
alarm_actions = ["arn:aws:sns:ap-northeast-2:897722691159:petclinic-seoul-dev-alerts"] # 예: ["arn:aws:sns:ap-northeast-2:123456789012:petclinic-seoul-dev-alerts"]

# Parameter Store 접두사 (서울 리전용)
parameter_prefix = "/petclinic-seoul"
