# =============================================================================
# Frontend Hosting Layer - S3 + CloudFront 정적 웹사이트 호스팅
# =============================================================================
# 목적: 프론트엔드 애플리케이션을 S3와 CloudFront로 호스팅
# 의존성: 08-api-gateway 레이어 (API Gateway 정보 참조)
# 개선사항: 공유 변수 서비스 적용, 표준화된 상태 참조

# 공통 로컬 변수(공유 변수 서비스 기반)
locals {
  # API Gateway 레이어에서 필요한 정보
  api_gateway_domain_name = data.terraform_remote_state.api_gateway.outputs.api_gateway_invoke_url

  # Frontend 호스팅 공통 설정
  layer_common_tags = merge(var.tags, {
    Layer     = "11-frontend"
    Component = "frontend-hosting"
    Purpose   = "s3-cloudfront-hosting"
  })
}


# =============================================================================
# S3 Frontend Hosting 모듈
# =============================================================================
module "s3_frontend" {
  source = "../../modules/s3-frontend"

  # 기본 설정
  name_prefix = var.name_prefix
  environment = var.environment
  tags        = local.layer_common_tags

  # 버저닝 설정
  enable_versioning = var.enable_versioning

  # 로깅 설정
  enable_access_logging = var.enable_access_logging
  log_retention_days    = var.log_retention_days

  # CORS 설정
  enable_cors = var.enable_cors
}

# =============================================================================
# CloudFront Distribution 모듈
# =============================================================================
module "cloudfront" {
  source = "../../modules/cloudfront"

  # 기본 설정
  name_prefix = var.name_prefix
  environment = var.environment
  tags        = local.layer_common_tags

  # S3 버킷 정보
  s3_bucket_name               = module.s3_frontend.bucket_name
  s3_bucket_regional_domain_name = module.s3_frontend.bucket_regional_domain_name
  cloudfront_oai_path          = module.s3_frontend.cloudfront_oai_path

  # API Gateway 통합
  enable_api_gateway_integration = true
  api_gateway_domain_name        = local.api_gateway_domain_name

  # CloudFront 설정
  price_class = var.price_class

  # SPA 라우팅
  enable_spa_routing = true

  # CORS 헤더
  enable_cors_headers = false

  # SSL/TLS 설정 (로컬 테스트용으로 HTTP 허용)
  use_default_certificate = var.use_default_certificate
  acm_certificate_arn     = var.acm_certificate_arn

  # 로깅 설정
  enable_logging         = false
  log_bucket_domain_name = module.s3_frontend.bucket_regional_domain_name
  log_prefix             = var.log_prefix

  # WAF 설정
  web_acl_arn = var.web_acl_arn

  # 모니터링 설정
  enable_monitoring     = var.enable_monitoring
  error_4xx_threshold   = var.error_4xx_threshold
  error_5xx_threshold   = var.error_5xx_threshold
  alarm_actions         = var.alarm_actions
}