# ==========================================
# Terraform 원격 상태 백엔드 설정
# ==========================================
# 이 파일은 자동 생성되었습니다. 수동으로 편집하지 마세요.

terraform {
  backend "s3" {
    bucket         = "${bucket}"
    key            = "${key}"
    region         = "${region}"
    dynamodb_table = "${dynamodb_table}"
    encrypt        = true
    kms_key_id     = "${kms_key_id}"
    
    # 추가 보안 설정
    skip_credentials_validation = false
    skip_metadata_api_check     = false
    skip_region_validation      = false
    force_path_style           = false
  }
}

# ==========================================
# 백엔드 설정 검증
# ==========================================
# 백엔드가 올바르게 설정되었는지 확인하는 데이터 소스
data "terraform_remote_state" "validation" {
  backend = "s3"
  config = {
    bucket = "${bucket}"
    key    = "${key}"
    region = "${region}"
  }
}