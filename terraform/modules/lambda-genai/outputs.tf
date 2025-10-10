# Lambda GenAI 모듈 출력값 - 단순화됨

# Lambda 함수 기본 정보
output "lambda_function_name" {
  description = "Lambda 함수 이름"
  value       = aws_lambda_function.genai_function.function_name
}

output "lambda_function_arn" {
  description = "Lambda 함수 ARN"
  value       = aws_lambda_function.genai_function.arn
}

output "lambda_function_invoke_arn" {
  description = "Lambda 함수 호출 ARN (API Gateway 통합용)"
  value       = aws_lambda_function.genai_function.invoke_arn
}