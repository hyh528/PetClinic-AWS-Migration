# Lambda GenAI 모듈 출력값

# Lambda 함수 정보
output "lambda_function_name" {
  description = "Lambda 함수 이름"
  value       = aws_lambda_function.genai_function.function_name
}

output "lambda_function_arn" {
  description = "Lambda 함수 ARN"
  value       = aws_lambda_function.genai_function.arn
}

output "lambda_function_qualified_arn" {
  description = "Lambda 함수 별칭 포함 ARN"
  value       = aws_lambda_alias.genai_function_alias.arn
}

output "lambda_function_invoke_arn" {
  description = "Lambda 함수 호출 ARN (API Gateway 통합용)"
  value       = aws_lambda_alias.genai_function_alias.invoke_arn
}

output "lambda_function_version" {
  description = "Lambda 함수 버전"
  value       = aws_lambda_function.genai_function.version
}

output "lambda_alias_name" {
  description = "Lambda 함수 별칭 이름"
  value       = aws_lambda_alias.genai_function_alias.name
}

# IAM 역할 정보
output "lambda_execution_role_arn" {
  description = "Lambda 실행 역할 ARN"
  value       = aws_iam_role.lambda_execution_role.arn
}

output "lambda_execution_role_name" {
  description = "Lambda 실행 역할 이름"
  value       = aws_iam_role.lambda_execution_role.name
}

# CloudWatch 로그 그룹
output "lambda_log_group_name" {
  description = "Lambda CloudWatch 로그 그룹 이름"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "lambda_log_group_arn" {
  description = "Lambda CloudWatch 로그 그룹 ARN"
  value       = aws_cloudwatch_log_group.lambda_logs.arn
}

# 모니터링 정보
output "lambda_error_alarm_name" {
  description = "Lambda 에러 알람 이름"
  value       = var.enable_monitoring ? aws_cloudwatch_metric_alarm.lambda_error_rate[0].alarm_name : null
}

output "lambda_duration_alarm_name" {
  description = "Lambda 실행 시간 알람 이름"
  value       = var.enable_monitoring ? aws_cloudwatch_metric_alarm.lambda_duration[0].alarm_name : null
}

output "lambda_concurrent_executions_alarm_name" {
  description = "Lambda 동시 실행 수 알람 이름"
  value       = var.enable_monitoring ? aws_cloudwatch_metric_alarm.lambda_concurrent_executions[0].alarm_name : null
}

# Bedrock 설정 정보
output "bedrock_model_id" {
  description = "사용 중인 Bedrock 모델 ID"
  value       = var.bedrock_model_id
}

# 성능 설정 정보
output "provisioned_concurrency_enabled" {
  description = "프로비저닝된 동시 실행 활성화 여부"
  value       = var.provisioned_concurrency_count > 0
}

output "provisioned_concurrency_count" {
  description = "프로비저닝된 동시 실행 수"
  value       = var.provisioned_concurrency_count
}