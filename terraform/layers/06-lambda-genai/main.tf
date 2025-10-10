# =============================================================================
# Lambda GenAI Layer - GenAI ECS 서비스를 Lambda + Bedrock으로 대체 (단순화됨)
# =============================================================================
# 목적: 서버리스 AI 서비스 제공 (기본 기능만)
# 의존성: 01-network, 02-security 레이어

# 공통 로컬 변수
locals {
  # Lambda GenAI 공통 설정 (공유 변수 시스템 사용)
  common_tags = merge(var.shared_config.common_tags, {
    Layer     = "06-lambda-genai"
    Component = "serverless-ai"
    Purpose   = "genai-service-replacement"
  })
}

# =============================================================================
# Lambda GenAI 모듈 (단순화됨)
# =============================================================================

module "lambda_genai" {
  source = "../../modules/lambda-genai"

  # 기본 설정 (공유 변수 시스템 사용)
  name_prefix = var.shared_config.name_prefix
  environment = var.shared_config.environment

  # Bedrock 설정 (기본값 사용)
  bedrock_model_id = var.bedrock_model_id

  # 공통 태그 적용
  tags = local.common_tags
}
