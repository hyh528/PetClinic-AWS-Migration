# =============================================================================
# AWS Native Services Integration Module - Outputs
# =============================================================================

# =============================================================================
# API Gateway 통합 출력
# =============================================================================

output "genai_resource_id" {
  description = "GenAI API 리소스 ID"
  value       = var.enable_genai_integration ? aws_api_gateway_resource.genai_resource[0].id : null
}

output "genai_method_id" {
  description = "GenAI API 메서드 ID"
  value       = var.enable_genai_integration ? aws_api_gateway_method.genai_method[0].id : null
}

output "genai_integration_id" {
  description = "GenAI API 통합 ID"
  value       = var.enable_genai_integration ? aws_api_gateway_integration.genai_integration[0].id : null
}

# =============================================================================
# 모니터링 및 알람 출력
# =============================================================================

output "api_gateway_4xx_alarm_arn" {
  description = "API Gateway 4xx 에러 알람 ARN"
  value       = var.enable_monitoring ? aws_cloudwatch_metric_alarm.api_gateway_4xx_errors[0].arn : null
}

output "lambda_genai_error_alarm_arn" {
  description = "Lambda GenAI 에러 알람 ARN"
  value       = var.enable_monitoring && var.enable_genai_integration ? aws_cloudwatch_metric_alarm.lambda_genai_errors[0].arn : null
}

output "integration_dashboard_arn" {
  description = "통합 대시보드 ARN"
  value       = var.create_integration_dashboard ? aws_cloudwatch_dashboard.aws_native_integration[0].dashboard_arn : null
}

# =============================================================================
# 보안 출력
# =============================================================================

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = var.enable_waf_protection ? aws_wafv2_web_acl.api_gateway_protection[0].arn : null
}

output "waf_web_acl_association_id" {
  description = "WAF Web ACL 연결 ID"
  value       = var.enable_waf_protection ? aws_wafv2_web_acl_association.api_gateway_waf_association[0].id : null
}

# =============================================================================
# 헬스체크 출력
# =============================================================================

output "health_check_id" {
  description = "Route 53 헬스체크 ID"
  value       = var.enable_health_checks ? aws_route53_health_check.api_gateway_health[0].id : null
}

# =============================================================================
# Lambda 권한 출력
# =============================================================================

output "lambda_permission_statement_id" {
  description = "Lambda 권한 Statement ID"
  value       = var.enable_genai_integration ? aws_lambda_permission.api_gateway_invoke[0].statement_id : null
}