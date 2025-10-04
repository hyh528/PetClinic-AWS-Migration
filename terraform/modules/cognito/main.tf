# Cognito 모듈 메인 파일
# 이 파일은 AWS Cognito 사용자 풀 및 사용자 풀 클라이언트를 생성합니다.

# Cognito User Pool 생성
resource "aws_cognito_user_pool" "this" {
  # User Pool의 이름입니다.
  name = "${var.project_name}-${var.environment}-user-pool"

  # 사용자 이름 속성 설정 (이메일을 사용자 이름으로 사용)
  username_attributes = ["email"]
  # 자동 검증 속성 (이메일)
  auto_verified_attributes = ["email"]

  # 비밀번호 정책 설정
  password_policy {
    minimum_length    = var.password_min_length
    require_lowercase = var.password_require_lowercase
    require_numbers   = var.password_require_numbers
    require_symbols   = var.password_require_symbols
    require_uppercase = var.password_require_uppercase
  }

  # MFA (Multi-Factor Authentication) 설정 (선택 사항)
  # mfa_configuration = "OFF" # OFF, ON, OPTIONAL

  # 메시지 사용자 지정 (선택 사항)
  # email_configuration {
  #   email_sending_account = "COGNITO_DEFAULT"
  #   from_email_address    = "noreply@example.com"
  #   source_arn            = "arn:aws:ses:REGION:ACCOUNT_ID:identity/example.com"
  # }

  # 태그
  tags = {
    Name        = "${var.project_name}-${var.environment}-user-pool"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Cognito User Pool 클라이언트 생성
resource "aws_cognito_user_pool_client" "this" {
  # User Pool ID입니다.
  user_pool_id = aws_cognito_user_pool.this.id
  # 클라이언트 이름입니다.
  name         = "${var.project_name}-${var.environment}-app-client"

  # 허용된 OAuth 흐름
  allowed_oauth_flows = [
    "code",
    "implicit",
  ]
  # 허용된 OAuth 범위
  allowed_oauth_scopes = [
    "phone",
    "email",
    "openid",
    "profile",
    "aws.cognito.signin.user.admin",
  ]
  # 허용된 콜백 URL (애플리케이션의 로그인 후 리다이렉트 URL)
  allowed_oauth_flows_user_pool_client = true
  callback_urls                        = var.cognito_callback_urls
  logout_urls                          = var.cognito_logout_urls

  # 토큰 유효 기간 설정 (분 단위 명시)
  access_token_validity  = var.access_token_validity_minutes
  id_token_validity      = var.id_token_validity_minutes
  refresh_token_validity = 30 # 30일

  # 단위 명시
  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  # 클라이언트 시크릿 생성 여부 (서버 측 애플리케이션의 경우 true)
  generate_secret = true
}
