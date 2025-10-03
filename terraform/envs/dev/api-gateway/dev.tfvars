# API Gateway 레이어 개발 환경 변수
# 단일 책임: API Gateway 설정만 관리

# 기본 설정
name_prefix = "petclinic-dev"
environment = "dev"
aws_region  = "ap-northeast-2"

# Terraform 상태 관리
tfstate_bucket_name = "petclinic-tfstate-team-jungsu-kopo"

# 다른 레이어 상태 파일 접근 프로필
network_state_profile     = "petclinic-yeonghyeon"
security_state_profile    = "petclinic-hwigwon"
application_state_profile = "petclinic-seokgyeom"

# API Gateway 설정
stage_name                = "v1"
throttle_rate_limit       = 1000
throttle_burst_limit      = 2000
integration_timeout_ms    = 29000
log_retention_days        = 14

# Lambda 통합 설정 (GenAI 서비스용)
enable_lambda_integration     = false  # 초기에는 비활성화, Lambda 배포 후 활성화
lambda_function_invoke_arn    = null   # Lambda 배포 후 설정
lambda_integration_timeout_ms = 29000

# 기능 활성화
enable_xray_tracing = true
enable_cors         = true
create_usage_plan   = false  # 개발 환경에서는 비활성화

# 모니터링 설정
enable_monitoring = true
create_dashboard  = true
alarm_actions     = []  # SNS 토픽 ARN 추가 시 설정

# 알람 임계값 (개발 환경용)
error_4xx_threshold           = 20   # 개발 환경에서는 높게 설정
error_5xx_threshold           = 10   # 5XX 에러는 낮게 유지
latency_threshold             = 2000 # 개발 환경에서는 2초
integration_latency_threshold = 1500 # 통합 지연시간 1.5초

# AWS 프로필
aws_profile = "petclinic-seokgyeom"

# 태그
tags = {
  Project     = "petclinic"
  Environment = "dev"
  ManagedBy   = "terraform"
  Layer       = "api-gateway"
  Owner       = "team-petclinic"
  CostCenter  = "training"
  Purpose     = "spring-cloud-gateway-replacement"
}