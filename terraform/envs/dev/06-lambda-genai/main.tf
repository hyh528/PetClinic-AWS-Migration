# Lambda GenAI 레이어 - GenAI ECS 서비스를 Lambda + Bedrock으로 대체

# Lambda GenAI 모듈 호출
module "lambda_genai" {
  source = "../../../modules/lambda-genai"

  # 기본 설정
  name_prefix = var.name_prefix
  environment = var.environment
  aws_region  = var.aws_region
  tags        = var.tags

  # Lambda 함수 설정
  runtime     = var.lambda_runtime
  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size
  log_level   = var.log_level

  # Bedrock 설정
  bedrock_model_id = var.bedrock_model_id

  # API Gateway 통합 (API Gateway 레이어에서 가져옴)
  api_gateway_execution_arn = data.terraform_remote_state.api_gateway.outputs.api_gateway_execution_arn

  # 모니터링 설정
  enable_monitoring    = var.enable_monitoring
  enable_xray_tracing = var.enable_xray_tracing
  
  # 알람 임계값
  error_threshold                   = var.error_threshold
  duration_threshold               = var.duration_threshold
  concurrent_executions_threshold  = var.concurrent_executions_threshold

  # 성능 최적화 (개발 환경에서는 비활성화)
  provisioned_concurrency_count = var.provisioned_concurrency_count

  # 환경 변수
  environment_variables = var.environment_variables
}