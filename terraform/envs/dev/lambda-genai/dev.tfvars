# Lambda GenAI 레이어 개발 환경 변수

# 기본 설정
name_prefix = "petclinic"
environment = "dev"
aws_region  = "ap-northeast-2"
aws_profile = "default"

# Lambda 함수 설정
lambda_runtime     = "python3.11"
lambda_timeout     = 30
lambda_memory_size = 512
log_level         = "INFO"

# Bedrock 설정
bedrock_model_id = "anthropic.claude-3-haiku-20240307-v1:0"

# 모니터링 설정
enable_monitoring   = true
enable_xray_tracing = true

# 알람 임계값 (개발 환경용)
error_threshold                  = 10    # 개발 환경에서는 높게 설정
duration_threshold              = 25000  # 25초
concurrent_executions_threshold = 50     # 개발 환경에서는 낮게 설정

# 성능 최적화 (개발 환경에서는 비활성화)
provisioned_concurrency_count = 0

# 환경 변수
environment_variables = {
  ENVIRONMENT  = "dev"
  SERVICE_NAME = "genai"
  DEBUG_MODE   = "true"
}

# Terraform 상태 관리
tfstate_bucket_name  = "petclinic-terraform-state-dev"
tf_lock_table_name   = "petclinic-terraform-lock"
encrypt_state        = true

# 원격 상태 접근 프로파일
api_gateway_state_profile = "default"