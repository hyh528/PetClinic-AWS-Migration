# Cloud Map 레이어 출력값 - 단일 책임 원칙 적용

# 네임스페이스 정보
output "namespace_id" {
  description = "프라이빗 DNS 네임스페이스 ID"
  value       = module.cloud_map.namespace_id
}

output "namespace_arn" {
  description = "프라이빗 DNS 네임스페이스 ARN"
  value       = module.cloud_map.namespace_arn
}

output "namespace_name" {
  description = "프라이빗 DNS 네임스페이스 이름"
  value       = module.cloud_map.namespace_name
}

output "namespace_hosted_zone" {
  description = "네임스페이스 호스팅 영역 ID"
  value       = module.cloud_map.namespace_hosted_zone
}

# 서비스 정보
output "services" {
  description = "생성된 서비스 디스커버리 서비스 정보"
  value       = module.cloud_map.services
}

output "service_ids" {
  description = "서비스 디스커버리 서비스 ID 목록"
  value       = module.cloud_map.service_ids
}

output "service_dns_names" {
  description = "각 마이크로서비스의 DNS 이름"
  value       = module.cloud_map.service_dns_names
}

output "service_discovery_endpoints" {
  description = "서비스 디스커버리 엔드포인트 정보"
  value       = module.cloud_map.service_discovery_endpoints
}

# ECS 통합 정보
output "ecs_integration_info" {
  description = "ECS 서비스 통합을 위한 정보"
  value       = module.cloud_map.ecs_integration_info
}

# 설정 정보
output "dns_configuration" {
  description = "DNS 설정 정보"
  value       = module.cloud_map.dns_configuration
}

output "health_check_configuration" {
  description = "헬스체크 설정 정보"
  value       = module.cloud_map.health_check_configuration
}

# 모니터링 정보
output "monitoring_info" {
  description = "모니터링 설정 정보"
  value       = module.cloud_map.monitoring_info
}

output "health_alarms" {
  description = "생성된 헬스체크 알람 정보"
  value       = module.cloud_map.health_alarms
}

# Spring Boot 애플리케이션 설정 정보
output "spring_application_config" {
  description = "Spring Boot 애플리케이션에서 사용할 서비스 디스커버리 설정"
  value = {
    # DNS 기반 서비스 호출 예시
    service_urls = {
      for service_name, dns_info in module.cloud_map.service_discovery_endpoints :
      service_name => "http://${dns_info.dns_name}:${dns_info.port}"
    }
    
    # RestTemplate/WebClient 설정용
    eureka_replacement_config = {
      "eureka.client.enabled"                    = "false"
      "spring.cloud.discovery.enabled"          = "false"
      "spring.cloud.loadbalancer.ribbon.enabled" = "false"
    }
  }
}

# 마이그레이션 상태
output "migration_status" {
  description = "Netflix Eureka 마이그레이션 상태"
  value = {
    eureka_discovery_replaced = true
    cloud_map_ready          = true
    namespace_name           = var.namespace_name
    registered_services      = var.microservices
    migration_date           = timestamp()
    vpc_id                   = data.terraform_remote_state.network.outputs.vpc_id
  }
}