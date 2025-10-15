# =============================================================================
# Common Module - 공통 태그 및 설정 관리
# =============================================================================
# 목적: 모든 레이어에서 사용하는 공통 태그와 설정을 중앙화하여 중복 제거

locals {
  # 공통 태그 계산 (중복 제거됨)
  # common_tags는 locals.tf에서 정의됨

  # 레이어 전용 태그 추가
  layer_tags = {
    "01-network" = merge(local.common_tags, {
      Layer     = "01-network"
      Component = "networking"
    })
    "02-security" = merge(local.common_tags, {
      Layer     = "02-security"
      Component = "security"
    })
    "03-database" = merge(local.common_tags, {
      Layer     = "03-database"
      Component = "database"
    })
    "04-parameter-store" = merge(local.common_tags, {
      Layer     = "04-parameter-store"
      Component = "configuration"
    })
    "05-cloud-map" = merge(local.common_tags, {
      Layer     = "05-cloud-map"
      Component = "service-discovery"
    })
    "06-lambda-genai" = merge(local.common_tags, {
      Layer     = "06-lambda-genai"
      Component = "ai-services"
    })
    "07-application" = merge(local.common_tags, {
      Layer     = "07-application"
      Component = "application"
    })
    "08-api-gateway" = merge(local.common_tags, {
      Layer     = "08-api-gateway"
      Component = "api-management"
    })
    "09-monitoring" = merge(local.common_tags, {
      Layer     = "09-monitoring"
      Component = "monitoring"
    })
    "10-aws-native" = merge(local.common_tags, {
      Layer     = "10-aws-native"
      Component = "integration"
    })
  }
}

# 공통 태그 출력
output "common_tags" {
  description = "모든 레이어에서 사용하는 공통 태그"
  value       = local.common_tags
}

# 레이어 전용 태그 출력
output "layer_tags" {
  description = "레이어별 전용 태그 맵"
  value       = local.layer_tags
}

# 특정 레이어 태그 조회
output "get_layer_tags" {
  description = "특정 레이어의 태그를 반환"
  value = {
    for layer, tags in local.layer_tags : layer => tags
  }
}

# 특정 레이어의 태그만 반환
output "get_tags_for_layer" {
  description = "특정 레이어의 태그를 반환"
  value       = lookup(local.layer_tags, var.layer, local.common_tags)
}