# =============================================================================
# AWS Native Services Integration Layer Outputs
# =============================================================================

# =============================================================================
# API Gateway 통합 출력
# =============================================================================

output "genai_resource_id" {
  description = "GenAI API 리소스 ID"
  value       = module.aws_native_integration.genai_resource_id
}

output "genai_method_id" {
  description = "GenAI API 메서드 ID"
  value       = module.aws_native_integration.genai_method_id
}

output "genai_integration_id" {
  description = "GenAI API 통합 ID"
  value       = module.aws_native_integration.genai_integration_id
}

# =============================================================================
# 모니터링 및 알람 출력
# =============================================================================

output "api_gateway_4xx_alarm_arn" {
  description = "API Gateway 4xx 에러 알람 ARN"
  value       = module.aws_native_integration.api_gateway_4xx_alarm_arn
}

output "lambda_genai_error_alarm_arn" {
  description = "Lambda GenAI 에러 알람 ARN"
  value       = module.aws_native_integration.lambda_genai_error_alarm_arn
}

output "integration_dashboard_arn" {
  description = "통합 대시보드 ARN"
  value       = module.aws_native_integration.integration_dashboard_arn
}

# =============================================================================
# 보안 출력
# =============================================================================

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = module.aws_native_integration.waf_web_acl_arn
}

output "waf_web_acl_association_id" {
  description = "WAF Web ACL 연결 ID"
  value       = module.aws_native_integration.waf_web_acl_association_id
}

# =============================================================================
# 헬스체크 출력
# =============================================================================

output "health_check_id" {
  description = "Route 53 헬스체크 ID"
  value       = module.aws_native_integration.health_check_id
}

# =============================================================================
# Lambda 권한 출력
# =============================================================================

output "lambda_permission_statement_id" {
  description = "Lambda 권한 Statement ID"
  value       = module.aws_native_integration.lambda_permission_statement_id
}

# =============================================================================
# 통합 상태 요약
# =============================================================================

output "integration_status" {
  description = "AWS 네이티브 서비스 통합 상태 요약"
  value = {
    genai_integration_enabled = var.enable_genai_integration
    monitoring_enabled        = var.enable_monitoring
    waf_protection_enabled    = var.enable_waf_protection
    health_checks_enabled     = var.enable_health_checks
    dashboard_created         = var.create_integration_dashboard
  }
}