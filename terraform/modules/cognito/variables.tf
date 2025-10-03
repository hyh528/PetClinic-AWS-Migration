# Cognito 모듈에서 사용될 변수들을 정의합니다.

# 프로젝트 이름 변수
variable "project_name" {
  description = "태그 및 리소스 이름에 사용될 프로젝트 이름입니다."
  type        = string
}

# 환경 변수
variable "environment" {
  description = "태그 및 리소스 이름에 사용될 환경 이름입니다 (예: dev, prod)."
  type        = string
}

# 비밀번호 최소 길이 변수
variable "password_min_length" {
  description = "사용자 풀 비밀번호의 최소 길이입니다."
  type        = number
  default     = 8
}

# 비밀번호 소문자 포함 여부 변수
variable "password_require_lowercase" {
  description = "사용자 풀 비밀번호에 소문자가 포함되어야 하는지 여부입니다."
  type        = bool
  default     = true
}

# 비밀번호 숫자 포함 여부 변수
variable "password_require_numbers" {
  description = "사용자 풀 비밀번호에 숫자가 포함되어야 하는지 여부입니다."
  type        = bool
  default     = true
}

# 비밀번호 기호 포함 여부 변수
variable "password_require_symbols" {
  description = "사용자 풀 비밀번호에 기호가 포함되어야 하는지 여부입니다."
  type        = bool
  default     = true
}

# 비밀번호 대문자 포함 여부 변수
variable "password_require_uppercase" {
  description = "사용자 풀 비밀번호에 대문자가 포함되어야 하는지 여부입니다."
  type        = bool
  default     = true
}

# Cognito 클라이언트 콜백 URL 목록 변수
variable "cognito_callback_urls" {
  description = "성공적인 로그인 후 사용자가 리다이렉트될 URL 목록입니다."
  type        = list(string)
  default     = ["http://localhost:8080/login"] # 개발용 기본값
}

# Cognito 클라이언트 로그아웃 URL 목록 변수
variable "cognito_logout_urls" {
  description = "로그아웃 후 사용자가 리다이렉트될 URL 목록입니다."
  type        = list(string)
  default     = ["http://localhost:8080/logout"] # 개발용 기본값
}

# 액세스 토큰 유효 기간 (분) 변수
variable "access_token_validity_minutes" {
  description = "액세스 토큰의 유효 기간 (분)입니다 (5분 ~ 1440분)."
  type        = number
  default     = 60
}

# ID 토큰 유효 기간 (분) 변수
variable "id_token_validity_minutes" {
  description = "ID 토큰의 유효 기간 (분)입니다 (5분 ~ 1440분)."
  type        = number
  default     = 60
}