# ==========================================
# CloudWatch 모듈 출력값
# ==========================================

output "dashboard_url" {
  description = "CloudWatch 대시보드 URL"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.petclinic_dashboard.dashboard_name}"
}

output "dashboard_name" {
  description = "CloudWatch 대시보드 이름"
  value       = aws_cloudwatch_dashboard.petclinic_dashboard.dashboard_name
}

output "api_gateway_log_group_name" {
  description = "API Gateway 로그 그룹 이름"
  value       = aws_cloudwatch_log_group.api_gateway.name
}

output "lambda_log_group_name" {
  description = "Lambda 로그 그룹 이름"
  value       = aws_cloudwatch_log_group.lambda_genai.name
}