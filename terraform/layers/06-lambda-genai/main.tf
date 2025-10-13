# =============================================================================
# Lambda GenAI Layer - GenAI ECS 서비스를 Lambda + Bedrock으로 대체 (단순화됨)
# =============================================================================
# 목적: 서버리스 AI 서비스 제공 (기본 기능만)
# 의존성: 01-network, 02-security 레이어

# 공통 로컬 변수
locals {
  # Lambda GenAI 공통 설정
  layer_common_tags = merge(var.tags, {
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

  # 기본 설정
  name_prefix = var.name_prefix
  environment = var.environment

  # Bedrock 설정 (기본값 사용)
  bedrock_model_id = var.bedrock_model_id

  # 공통 태그 적용
  tags = local.layer_common_tags
}
