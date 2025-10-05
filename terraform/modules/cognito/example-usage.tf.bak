# Cognito 모듈 사용 예시
# 이 파일은 실제 환경에서 Cognito 모듈을 사용하는 방법을 보여줍니다.

# 개발 환경용 Cognito 설정
module "cognito_dev" {
  source = "./modules/cognito"

  # 기본 설정
  project_name = "petclinic"
  environment  = "dev"

  # 보안 설정 (개발 환경용 - 완화된 설정)
  mfa_configuration      = "OPTIONAL"
  advanced_security_mode = "AUDIT"
  admin_create_user_only = false

  # 비밀번호 정책 (개발 환경용)
  password_min_length         = 8
  password_require_lowercase  = true
  password_require_numbers    = true
  password_require_symbols    = false  # 개발 편의성
  password_require_uppercase  = true

  # OAuth 설정
  allowed_oauth_flows = ["code", "implicit"]
  
  # 개발 환경 URL
  cognito_callback_urls = [
    "http://localhost:8080/login/oauth2/code/cognito",
    "https://dev-petclinic.example.com/login/oauth2/code/cognito"
  ]
  
  cognito_logout_urls = [
    "http://localhost:8080/logout",
    "https://dev-petclinic.example.com/logout"
  ]

  # 토큰 설정 (개발용 - 짧은 유효기간)
  access_token_validity_minutes = 60    # 1시간
  id_token_validity_minutes     = 60    # 1시간
  refresh_token_validity_days   = 7     # 7일

  # 클라이언트 설정
  generate_client_secret = true
  create_identity_pool   = false  # 개발 환경에서는 불필요
}

# 프로덕션 환경용 Cognito 설정
module "cognito_prod" {
  source = "./modules/cognito"

  # 기본 설정
  project_name = "petclinic"
  environment  = "prod"

  # 보안 설정 (프로덕션 환경용 - 강화된 설정)
  mfa_configuration      = "ON"        # MFA 필수
  advanced_security_mode = "ENFORCED"  # 고급 보안 강제
  admin_create_user_only = true        # 관리자만 사용자 생성

  # 비밀번호 정책 (프로덕션 환경용 - 강화)
  password_min_length         = 12
  password_require_lowercase  = true
  password_require_numbers    = true
  password_require_symbols    = true
  password_require_uppercase  = true

  # OAuth 설정
  allowed_oauth_flows = ["code"]  # Authorization Code만 허용

  # 프로덕션 환경 URL
  cognito_callback_urls = [
    "https://petclinic.example.com/login/oauth2/code/cognito"
  ]
  
  cognito_logout_urls = [
    "https://petclinic.example.com/logout"
  ]

  # 토큰 설정 (프로덕션용 - 보안 강화)
  access_token_validity_minutes = 30    # 30분
  id_token_validity_minutes     = 30    # 30분
  refresh_token_validity_days   = 30    # 30일

  # 클라이언트 설정
  generate_client_secret = true
  create_identity_pool   = true   # AWS 서비스 접근용

  # 커스텀 도메인 (선택사항)
  # custom_domain    = "auth.petclinic.example.com"
  # certificate_arn  = "arn:aws:acm:region:account:certificate/cert-id"
}

# 출력 예시
output "dev_cognito_info" {
  description = "개발 환경 Cognito 정보"
  value = {
    user_pool_id     = module.cognito_dev.user_pool_id
    client_id        = module.cognito_dev.user_pool_client_id
    hosted_ui_url    = module.cognito_dev.user_pool_hosted_ui_url
    oauth_endpoints  = module.cognito_dev.oauth_endpoints
  }
}

output "prod_cognito_info" {
  description = "프로덕션 환경 Cognito 정보"
  value = {
    user_pool_id     = module.cognito_prod.user_pool_id
    client_id        = module.cognito_prod.user_pool_client_id
    hosted_ui_url    = module.cognito_prod.user_pool_hosted_ui_url
    identity_pool_id = module.cognito_prod.identity_pool_id
  }
  sensitive = false
}