# Lambda GenAI 레이어 출력값 - 단순화됨

# Lambda 함수 기본 정보
output "lambda_function_name" {
  description = "Lambda 함수 이름"
  value       = module.lambda_genai.lambda_function_name
}

output "lambda_function_arn" {
  description = "Lambda 함수 ARN"
  value       = module.lambda_genai.lambda_function_arn
}

output "lambda_function_invoke_arn" {
  description = "Lambda 함수 호출 ARN (API Gateway 통합용)"
  value       = module.lambda_genai.lambda_function_invoke_arn
}

# 호환성을 위한 별칭 출력값 (10-aws-native 레이어에서 참조)
output "function_name" {
  description = "Lambda 함수 이름 (호환성 별칭)"
  value       = module.lambda_genai.lambda_function_name
}

output "function_arn" {
  description = "Lambda 함수 ARN (호환성 별칭)"
  value       = module.lambda_genai.lambda_function_arn
}

# Bedrock 설정 정보
output "bedrock_model_id" {
  description = "사용 중인 Bedrock 모델 ID"
  value       = var.bedrock_model_id
}