resource "aws_service_discovery_private_dns_namespace" "this" {
  name = var.namespace_name
  description = "Petclinic 마이크로서비스용 Private DNS 네임스페이스"
  vpc = var.vpc_id
}

resource "aws_service_discovery_service" "this" {
  for_each = var.service_name_map

  name = each.key # service_name_map의 key
  description = each.value # service_name_map의 value

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id

    dns_records {
      ttl = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
    # Spring Boot Actuator의 health check를 사용하지 않으므로, 실패 임계값을 비활성화합니다.
    # 애플리케이션이 직접 자신의 상태를 Cloud Map에 보고하게 됩니다.
  }
}