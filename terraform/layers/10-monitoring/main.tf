# ==========================================
# Monitoring 레이어: CloudWatch 통합 모니터링
# ==========================================
# AWS 네이티브 서비스들의 통합 모니터링 시스템

# 공통 로컬 변수
locals {
  # 각 레이어에서 필요한 정보
  api_gateway_name     = "petclinic-api"                # 고정값 사용
  lambda_function_name = "petclinic-dev-genai-function" # 고정값 사용
  aurora_cluster_name  = data.terraform_remote_state.database.outputs.cluster_identifier
  alb_name             = data.terraform_remote_state.application.outputs.alb_dns_name
}

# CloudWatch 모니터링 모듈 호출
module "cloudwatch" {
  source = "../../modules/cloudwatch"

  dashboard_name = "${var.name_prefix}-${var.environment}-Dashboard"
  aws_region     = var.aws_region

  # 각 레이어에서 가져온 리소스 정보 (의존성 역전)
  api_gateway_name     = local.api_gateway_name
  ecs_cluster_name     = data.terraform_remote_state.application.outputs.ecs_cluster_name
  lambda_function_name = local.lambda_function_name
  aurora_cluster_name  = local.aurora_cluster_name
  
  # 멀티 서비스 지원 (CloudMap 아키텍처)
  ecs_services = data.terraform_remote_state.application.outputs.ecs_services
  alb_arn_suffix = data.terraform_remote_state.application.outputs.alb_arn_suffix
  target_groups  = data.terraform_remote_state.application.outputs.target_group_arns

  # 레거시 단일 서비스 지원 (하위 호환성)
  ecs_service_name = try(data.terraform_remote_state.application.outputs.ecs_services["customers"].service_name, "")
  alb_name         = try(data.terraform_remote_state.application.outputs.alb_dns_name, "")

  log_retention_days = 30
  sns_topic_arn      = var.sns_topic_arn

  tags = var.tags
}

# CloudTrail 감사 로그 모듈 호출
module "cloudtrail" {
  source = "../../modules/cloudtrail"

  cloudtrail_name        = "${var.name_prefix}-${var.environment}-audit-trail"
  cloudtrail_bucket_name = "${var.name_prefix}-${var.environment}-cloudtrail-logs"
  aws_region             = var.aws_region
  log_retention_days     = 90
  sns_topic_arn          = var.sns_topic_arn

  tags = var.tags
}
