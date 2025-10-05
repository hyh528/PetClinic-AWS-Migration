# 도쿄 리전 테스트용 변수 파일
# 영현님 개인 테스트 환경

# 리전 변경: 서울 -> 도쿄
aws_region = "ap-northeast-1"
aws_profile = "petclinic-yeonghyeon"

# 도쿄 리전 가용 영역
azs = ["ap-northeast-1a", "ap-northeast-1c"]

# 테스트 환경 식별
name_prefix = "petclinic-tokyo-test"
environment = "test"

# 네트워크 설정 (기본값 유지)
vpc_cidr = "10.0.0.0/16"
enable_ipv6 = true

public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
private_app_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
private_db_subnet_cidrs = ["10.0.5.0/24", "10.0.6.0/24"]

create_nat_per_az = true

# 테스트 태그
tags = {
  Purpose = "tokyo-region-test"
  Owner   = "yeonghyeon"
  TestEnv = "true"
}