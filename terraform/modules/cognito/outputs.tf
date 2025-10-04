# Cognito 모듈의 출력 값들을 정의합니다.

# Cognito User Pool ID 출력
output "user_pool_id" {
  description = "생성된 Cognito User Pool의 ID입니다."
  value       = aws_cognito_user_pool.this.id
}

# Cognito User Pool ARN 출력
output "user_pool_arn" {
  description = "생성된 Cognito User Pool의 ARN입니다."
  value       = aws_cognito_user_pool.this.arn
}

# Cognito User Pool 클라이언트 ID 출력
output "user_pool_client_id" {
  description = "생성된 Cognito User Pool 클라이언트의 ID입니다."
  value       = aws_cognito_user_pool_client.this.id
}

# Cognito User Pool 클라이언트 시크릿 출력 (민감 정보)
# 서버 측 애플리케이션용으로, 민감 정보이므로 출력 시 숨겨집니다.
output "user_pool_client_secret" {
  description = "생성된 Cognito User Pool 클라이언트의 시크릿입니다 (서버 측 애플리케이션용)."
  value       = aws_cognito_user_pool_client.this.client_secret
  sensitive   = true
}
