# Cloud Map 레이어 개발 환경 변수
# 단일 책임: Cloud Map 서비스 디스커버리 설정만 관리

# 기본 설정
name_prefix = "petclinic-dev"
environment = "dev"
aws_region  = "ap-northeast-2"

# Terraform 상태 관리
tfstate_bucket_name = "petclinic-tfstate-team-jungsu-kopo"

# 다른 레이어 상태 파일 접근 프로필
network_state_profile = "petclinic-yeonghyeon"

# Cloud Map 설정
namespace_name        = "petclinic.local"
namespace_description = "PetClinic 마이크로서비스 서비스 디스커버리 (개발 환경)"

# 마이크로서비스 목록
microservices = [
  "customers",
  "vets", 
  "visits",
  "admin"
]

# DNS 설정
dns_ttl         = 60          # 개발 환경에서는 짧은 TTL
dns_record_type = "A"
routing_policy  = "MULTIVALUE"

# 헬스체크 설정
health_check_grace_period      = 30    # 30초 유예 기간
enable_custom_health_check     = false # 개발 환경에서는 기본 헬스체크 사용
health_check_failure_threshold = 3

# 모니터링 설정
enable_logging      = false # 개발 환경에서는 로깅 비활성화
enable_metrics      = false # 개발 환경에서는 메트릭 비활성화
enable_health_alarms = true  # 헬스 알람은 활성화
log_retention_days  = 30
healthy_instance_threshold = 1  # 최소 1개 인스턴스 필요
alarm_actions       = []    # SNS 토픽 ARN 추가 시 설정

# 고급 설정
force_destroy = true  # 개발 환경에서는 강제 삭제 허용

# AWS 프로필
aws_profile = "petclinic-seokgyeom"

# 태그
tags = {
  Project     = "petclinic"
  Environment = "dev"
  ManagedBy   = "terraform"
  Layer       = "cloud-map"
  Owner       = "team-petclinic"
  CostCenter  = "training"
  Purpose     = "eureka-discovery-replacement"
}