# 개선된 Cognito 모듈 출력 정의
# 추가 리소스 및 유용한 정보 출력

# User Pool 관련 출력
output "user_pool_id" {
  description = "생성된 Cognito User Pool의 ID입니다."
  value       = aws_cognito_user_pool.this.id
}

output "user_pool_arn" {
  description = "생성된 Cognito User Pool의 ARN입니다."
  value       = aws_cognito_user_pool.this.arn
}

output "user_pool_endpoint" {
  description = "Cognito User Pool의 엔드포인트입니다."
  value       = aws_cognito_user_pool.this.endpoint
}

output "user_pool_domain" {
  description = "Cognito User Pool의 도메인입니다."
  value       = aws_cognito_user_pool_domain.this.domain
}

output "user_pool_hosted_ui_url" {
  description = "Cognito Hosted UI URL입니다."
  value       = "https://${aws_cognito_user_pool_domain.this.domain}.auth.${data.aws_region.current.id}.amazoncognito.com"
}

# User Pool Client 관련 출력
output "user_pool_client_id" {
  description = "생성된 Cognito User Pool 클라이언트의 ID입니다."
  value       = aws_cognito_user_pool_client.this.id
}

output "user_pool_client_secret" {
  description = "생성된 Cognito User Pool 클라이언트의 시크릿입니다 (서버 측 애플리케이션용)."
  value       = var.generate_client_secret ? aws_cognito_user_pool_client.this.client_secret : null
  sensitive   = true
}

# Identity Pool 관련 출력 (조건부)
output "identity_pool_id" {
  description = "생성된 Cognito Identity Pool의 ID입니다."
  value       = var.create_identity_pool ? aws_cognito_identity_pool.this[0].id : null
}

output "identity_pool_arn" {
  description = "생성된 Cognito Identity Pool의 ARN입니다."
  value       = var.create_identity_pool ? aws_cognito_identity_pool.this[0].arn : null
}

# 유용한 설정 정보 출력
output "oauth_endpoints" {
  description = "OAuth 엔드포인트 정보입니다."
  value = {
    authorization = "https://${aws_cognito_user_pool_domain.this.domain}.auth.${data.aws_region.current.id}.amazoncognito.com/oauth2/authorize"
    token         = "https://${aws_cognito_user_pool_domain.this.domain}.auth.${data.aws_region.current.id}.amazoncognito.com/oauth2/token"
    userinfo      = "https://${aws_cognito_user_pool_domain.this.domain}.auth.${data.aws_region.current.id}.amazoncognito.com/oauth2/userInfo"
    logout        = "https://${aws_cognito_user_pool_domain.this.domain}.auth.${data.aws_region.current.id}.amazoncognito.com/logout"
  }
}

output "jwks_uri" {
  description = "JSON Web Key Set URI입니다."
  value       = "https://cognito-idp.${data.aws_region.current.id}.amazonaws.com/${aws_cognito_user_pool.this.id}/.well-known/jwks.json"
}

output "issuer" {
  description = "JWT 토큰 발급자 정보입니다."
  value       = "https://cognito-idp.${data.aws_region.current.id}.amazonaws.com/${aws_cognito_user_pool.this.id}"
}

# 현재 AWS 리전 정보
data "aws_region" "current" {}

# 설정 요약 출력
output "configuration_summary" {
  description = "Cognito 설정 요약 정보입니다."
  value = {
    mfa_enabled           = var.mfa_configuration != "OFF"
    advanced_security     = var.advanced_security_mode
    admin_create_only     = var.admin_create_user_only
    identity_pool_created = var.create_identity_pool
    custom_domain_used    = var.custom_domain != null
  }
}