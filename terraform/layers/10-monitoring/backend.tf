terraform {
  # 백엔드 유형만 선언합니다. 구체적인 백엔드 구성 값(버킷, key, region, dynamodb_table 등)은
  # init 시점에 -backend-config 파일들로 주입합니다(부분 구성, partial configuration).
  # 예시 초기화 명령(레이어 디렉터리에서):
  # terraform init -backend-config=../../backend.hcl -backend-config=backend.config -reconfigure
  backend "s3" {}
}