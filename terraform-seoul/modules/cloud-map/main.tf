# Cloud Map 모듈 - Netflix Eureka 대체 (단순화됨)
# 기본 DNS 기반 서비스 디스커버리만 제공

# 프라이빗 DNS 네임스페이스 생성
resource "aws_service_discovery_private_dns_namespace" "this" {
  name        = var.namespace_name
  description = "PetClinic 마이크로서비스 서비스 디스커버리"
  vpc         = var.vpc_id

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-service-discovery"
    Environment = var.environment
    Type        = "service-discovery"
  })
}

# 마이크로서비스별 서비스 생성 (기본 설정만)
resource "aws_service_discovery_service" "microservices" {
  for_each = toset(var.microservices)

  name = each.value

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id

    dns_records {
      ttl  = var.dns_ttl
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-${each.value}-service"
    Environment = var.environment
    Service     = each.value
    Type        = "service-discovery"
  })
}
