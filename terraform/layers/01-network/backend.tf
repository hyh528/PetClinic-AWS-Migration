terraform {
  # 백엔드 유형만 선언합니다. 구체적인 백엔드 구성 값(버킷, key, region, dynamodb_table 등)은
  # init 시점에 -backend-config 파일들로 주입합니다(부분 구성, partial configuration).
  # 이렇게 하면 환경별 state key를 소스에 하드코딩하지 않으면서도 중앙 스테이트를 사용합니다.
  #
  # 예시 초기화 명령(레이어 디렉터리에서):
  # terraform init -backend-config=../../backend.hcl -backend-config=backend.config -reconfigure
  # ../../backend.hcl 에는 공통 backend 설정(예: bucket, region, dynamodb_table)이 들어가고,
  # backend.config에는 레이어별 key 값(예: key = "dev/01-network/terraform.tfstate")이 들어갑니다.
  backend "s3" {}
}