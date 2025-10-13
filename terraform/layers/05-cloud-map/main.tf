# =============================================================================
# Cloud Map Layer - Netflix Eureka 대체 (단순화됨)
# =============================================================================
# 목적: 기본 DNS 기반 서비스 디스커버리만 담당
# 의존성: 01-network 레이어 (VPC ID)

# 공통 로컬 변수
locals {
  # Cloud Map 공통 설정
  common_tags = merge(var.tags, {
    Layer     = "05-cloud-map"
    Component = "service-discovery"
    Purpose   = "eureka-replacement"
  })
}

# =============================================================================
# 네트워크 레이어 상태 참조 (표준화된 경로)
# =============================================================================

# =============================================================================
# Cloud Map 모듈 (단순화됨)
# =============================================================================

module "cloud_map" {
  source = "../../modules/cloud-map"

  # 기본 설정
  name_prefix = var.name_prefix
  environment = var.environment

  # VPC 설정
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  # 네임스페이스 설정 (기본값 사용)
  namespace_name = "petclinic.local"

  # 마이크로서비스 목록 (ECS 서비스만)
  microservices = ["customers", "vets", "visits", "admin"]

  # 기본 DNS 설정만
  dns_ttl = 60

  # 공통 태그 적용
  tags = local.common_tags
}
