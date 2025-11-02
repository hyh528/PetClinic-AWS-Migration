# Terraform Backend Configuration
# 이 파일은 backend.config와 함께 사용됩니다.

terraform {
  backend "s3" {
    # 실제 설정은 backend.config 파일에서 로드됩니다.
    # terraform init -backend-config="../../backend.hcl" -backend-config="backend.config" 명령어로 초기화하세요.
  }
}