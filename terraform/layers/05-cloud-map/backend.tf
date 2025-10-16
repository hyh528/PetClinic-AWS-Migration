terraform {
  # 백엔드 유형만 선언합니다. 구체적인 백엔드 구성 값은 init 시점에 -backend-config로 제공합니다.
  # 예: terraform init -backend-config=../../backend.hcl -backend-config=backend.config -reconfigure
  backend "s3" {}
}