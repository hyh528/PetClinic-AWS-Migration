# Lambda GenAI 레이어 출력값

# Lambda 함수 정보
output "lambda_function_name" {
  description = "Lambda 함수 이름"
  value       = module.lambda_genai.lambda_function_name
}

output "lambda_function_arn" {
  description = "Lambda 함수 ARN"
  value       = module.lambda_genai.lambda_function_arn
}

output "lambda_function_qualified_arn" {
  description = "Lambda 함수 별칭 포함 ARN"
  value       = module.lambda_genai.lambda_function_qualified_arn
}

output "lambda_function_invoke_arn" {
  description = "Lambda 함수 호출 ARN (API Gateway 통합용)"
  value       = module.lambda_genai.lambda_function_invoke_arn
}

output "lambda_alias_name" {
  description = "Lambda 함수 별칭 이름"
  value       = module.lambda_genai.lambda_alias_name
}

# IAM 역할 정보
output "lambda_execution_role_arn" {
  description = "Lambda 실행 역할 ARN"
  value       = module.lambda_genai.lambda_execution_role_arn
}

output "lambda_execution_role_name" {
  description = "Lambda 실행 역할 이름"
  value       = module.lambda_genai.lambda_execution_role_name
}

# CloudWatch 로그 그룹
output "lambda_log_group_name" {
  description = "Lambda CloudWatch 로그 그룹 이름"
  value       = module.lambda_genai.lambda_log_group_name
}

# 모니터링 정보
output "lambda_error_alarm_name" {
  description = "Lambda 에러 알람 이름"
  value       = module.lambda_genai.lambda_error_alarm_name
}

output "lambda_duration_alarm_name" {
  description = "Lambda 실행 시간 알람 이름"
  value       = module.lambda_genai.lambda_duration_alarm_name
}

output "lambda_concurrent_executions_alarm_name" {
  description = "Lambda 동시 실행 수 알람 이름"
  value       = module.lambda_genai.lambda_concurrent_executions_alarm_name
}

# Bedrock 설정 정보
output "bedrock_model_id" {
  description = "사용 중인 Bedrock 모델 ID"
  value       = module.lambda_genai.bedrock_model_id
}

# 성능 설정 정보
output "provisioned_concurrency_enabled" {
  description = "프로비저닝된 동시 실행 활성화 여부"
  value       = module.lambda_genai.provisioned_concurrency_enabled
}