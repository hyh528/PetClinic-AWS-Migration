# Lambda GenAI 레이어 출력

output "lambda_function_arn" {
  description = "Lambda 함수 ARN"
  value       = aws_lambda_function.genai_function.arn
}

output "lambda_function_name" {
  description = "Lambda 함수 이름"
  value       = aws_lambda_function.genai_function.function_name
}

output "lambda_function_invoke_arn" {
  description = "Lambda 함수 호출 ARN (API Gateway 통합용)"
  value       = aws_lambda_function.genai_function.invoke_arn
}

output "lambda_execution_role_arn" {
  description = "Lambda 실행 역할 ARN"
  value       = aws_iam_role.lambda_execution_role.arn
}

output "lambda_security_group_id" {
  description = "Lambda 함수 보안 그룹 ID"
  value       = aws_security_group.lambda_sg.id
}