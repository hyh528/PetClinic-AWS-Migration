# Cloud Map 모듈 출력값 - 단순화됨

# 네임스페이스 정보 (기본 정보만)
output "namespace_id" {
  description = "프라이빗 DNS 네임스페이스 ID"
  value       = aws_service_discovery_private_dns_namespace.this.id
}

output "namespace_name" {
  description = "프라이빗 DNS 네임스페이스 이름"
  value       = aws_service_discovery_private_dns_namespace.this.name
}

# 서비스 정보 (기본 정보만)
output "service_ids" {
  description = "서비스 디스커버리 서비스 ID 목록"
  value = {
    for service_name, service in aws_service_discovery_service.microservices :
    service_name => service.id
  }
}

# 서비스 ARN 정보 (ECS service_registries에서 사용)
output "service_arns" {
  description = "서비스 디스커버리 서비스 ARN 목록"
  value = {
    for service_name, service in aws_service_discovery_service.microservices :
    service_name => service.arn
  }
}

# DNS 이름 정보
output "service_dns_names" {
  description = "각 마이크로서비스의 DNS 이름"
  value = {
    for service_name in var.microservices :
    service_name => "${service_name}.${var.namespace_name}"
  }
}