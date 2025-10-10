# Cloud Map 레이어 출력값 - 단순화됨

# 네임스페이스 정보 (기본 정보만)
output "namespace_id" {
  description = "프라이빗 DNS 네임스페이스 ID"
  value       = module.cloud_map.namespace_id
}

output "namespace_name" {
  description = "프라이빗 DNS 네임스페이스 이름"
  value       = module.cloud_map.namespace_name
}

# 서비스 정보 (기본 정보만)
output "service_ids" {
  description = "서비스 디스커버리 서비스 ID 목록"
  value       = module.cloud_map.service_ids
}

output "service_dns_names" {
  description = "각 마이크로서비스의 DNS 이름"
  value       = module.cloud_map.service_dns_names
}