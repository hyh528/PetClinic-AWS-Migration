# =============================================================================
# Frontend Hosting Layer - 간단하고 명확한 S3 + CloudFront 호스팅
# =============================================================================

locals {
  # API Gateway 정보 참조
  api_gateway_domain_name = data.terraform_remote_state.api_gateway.outputs.api_gateway_invoke_url

  # 공통 태그
  common_tags = merge(var.tags, {
    Layer = "11-frontend"
  })
}

# =============================================================================
# S3 Frontend Hosting
# =============================================================================
module "s3_frontend" {
  source = "../../modules/s3-frontend"

  name_prefix = var.name_prefix
  environment = var.environment
  tags        = local.common_tags

  enable_versioning     = var.enable_versioning
  enable_access_logging = var.enable_access_logging
  log_retention_days    = var.log_retention_days
  enable_cors           = var.enable_cors
}

# =============================================================================
# CloudFront Distribution
# =============================================================================
module "cloudfront" {
  source = "../../modules/cloudfront"

  name_prefix = var.name_prefix
  environment = var.environment
  tags        = local.common_tags

  # S3 연결
  s3_bucket_name                 = module.s3_frontend.bucket_name
  s3_bucket_regional_domain_name = module.s3_frontend.bucket_regional_domain_name
  cloudfront_oai_path            = module.s3_frontend.cloudfront_oai_path

  # API Gateway 통합
  enable_api_gateway_integration = true
  api_gateway_domain_name        = local.api_gateway_domain_name

  # 기본 설정
  price_class             = var.price_class
  enable_spa_routing      = true
  enable_cors_headers     = false
  use_default_certificate = var.use_default_certificate
  acm_certificate_arn     = var.acm_certificate_arn
  enable_logging          = false
  log_bucket_domain_name  = module.s3_frontend.bucket_regional_domain_name
  log_prefix              = var.log_prefix
  web_acl_arn             = var.web_acl_arn
  enable_monitoring       = var.enable_monitoring
  error_4xx_threshold     = var.error_4xx_threshold
  error_5xx_threshold     = var.error_5xx_threshold
  alarm_actions           = var.alarm_actions
}