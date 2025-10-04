# 개선된 Cognito 모듈 - 프로덕션 준비 버전
# 보안 강화 및 누락된 기능 추가

# Cognito User Pool 생성 (개선 버전)
resource "aws_cognito_user_pool" "this" {
  name = "${var.project_name}-${var.environment}-user-pool"

  # 사용자 이름 속성 설정
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # 비밀번호 정책 설정 (강화)
  password_policy {
    minimum_length                   = var.password_min_length
    require_lowercase                = var.password_require_lowercase
    require_numbers                  = var.password_require_numbers
    require_symbols                  = var.password_require_symbols
    require_uppercase                = var.password_require_uppercase
    temporary_password_validity_days = 7
  }

  # MFA 설정 (보안 강화)
  mfa_configuration = var.mfa_configuration

  # 사용자 속성 스키마 정의
  schema {
    attribute_data_type = "String"
    name                = "email"
    required            = true
    mutable             = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  schema {
    attribute_data_type = "String"
    name                = "name"
    required            = false
    mutable             = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  # 계정 복구 설정
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # 이메일 설정
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
    # 프로덕션에서는 SES 사용 권장
    # email_sending_account = "DEVELOPER"
    # source_arn = var.ses_source_arn
  }

  # 사용자 풀 정책
  user_pool_add_ons {
    advanced_security_mode = var.advanced_security_mode
  }

  # 관리자 생성 사용자 설정
  admin_create_user_config {
    allow_admin_create_user_only = var.admin_create_user_only

    invite_message_template {
      email_message = "안녕하세요! PetClinic에 오신 것을 환영합니다. 임시 비밀번호: {password}"
      email_subject = "PetClinic 계정 생성"
      sms_message   = "PetClinic 임시 비밀번호: {password}"
    }
  }

  # 사용자 풀 정책 (이미 위에서 password_policy로 정의됨)

  # 태그
  tags = {
    Name        = "${var.project_name}-${var.environment}-user-pool"
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "사용자 인증 및 권한 관리"
    ManagedBy   = "terraform"
  }
}

# Cognito User Pool 도메인 (누락된 기능 추가)
resource "aws_cognito_user_pool_domain" "this" {
  domain       = "${var.project_name}-${var.environment}-auth"
  user_pool_id = aws_cognito_user_pool.this.id

  # 커스텀 도메인 사용 시 (선택사항)
  # domain          = var.custom_domain
  # certificate_arn = var.certificate_arn
}

# Cognito User Pool 클라이언트 생성 (개선 버전)
resource "aws_cognito_user_pool_client" "this" {
  user_pool_id = aws_cognito_user_pool.this.id
  name         = "${var.project_name}-${var.environment}-app-client"

  # OAuth 설정
  allowed_oauth_flows = var.allowed_oauth_flows
  allowed_oauth_scopes = [
    "phone",
    "email",
    "openid",
    "profile",
    "aws.cognito.signin.user.admin",
  ]

  allowed_oauth_flows_user_pool_client = true
  callback_urls                        = var.cognito_callback_urls
  logout_urls                          = var.cognito_logout_urls

  # 토큰 유효 기간 설정
  access_token_validity  = var.access_token_validity_minutes
  id_token_validity      = var.id_token_validity_minutes
  refresh_token_validity = var.refresh_token_validity_days

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  # 보안 설정
  generate_secret                               = var.generate_client_secret
  prevent_user_existence_errors                 = "ENABLED"
  enable_token_revocation                       = true
  enable_propagate_additional_user_context_data = false

  # 읽기/쓰기 속성 설정
  read_attributes = [
    "email",
    "email_verified",
    "name",
  ]

  write_attributes = [
    "email",
    "name",
  ]

  # 명시적 인증 플로우
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]
}

# Identity Pool (선택사항 - AWS 서비스 접근용)
resource "aws_cognito_identity_pool" "this" {
  count                            = var.create_identity_pool ? 1 : 0
  identity_pool_name               = "${var.project_name}-${var.environment}-identity-pool"
  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.this.id
    provider_name           = aws_cognito_user_pool.this.endpoint
    server_side_token_check = false
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-identity-pool"
    Project     = var.project_name
    Environment = var.environment
  }
}