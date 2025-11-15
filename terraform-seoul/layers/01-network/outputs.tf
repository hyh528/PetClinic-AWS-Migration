
output "vpc_id" {
  description = "VPC 식별자"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC IPv4 CIDR 블록"
  value       = module.vpc.vpc_cidr
}

output "vpc_ipv6_cidr" {
  description = "VPC IPv6 CIDR 블록 (IPv6 비활성화 시 null)"
  value       = module.vpc.vpc_ipv6_cidr
}

output "public_subnet_ids" {
  description = "AZ 인덱스(0,1,...)로 키된 퍼블릭 서브넷 ID 맵"
  value       = module.vpc.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "AZ 인덱스(0,1,...)로 키된 프라이빗 앱 서브넷 ID 맵"
  value       = module.vpc.private_app_subnet_ids
}

output "private_db_subnet_ids" {
  description = "AZ 인덱스(0,1,...)로 키된 프라이빗 DB 서브넷 ID 맵"
  value       = module.vpc.private_db_subnet_ids
}

output "public_route_table_id" {
  description = "퍼블릭 라우트 테이블 ID"
  value       = module.vpc.public_route_table_id
}

output "private_app_route_table_ids" {
  description = "AZ 인덱스로 키된 프라이빗 앱 라우트 테이블 ID 맵"
  value       = module.vpc.private_app_route_table_ids
}

output "private_db_route_table_ids" {
  description = "AZ 인덱스로 키된 프라이빗 DB 라우트 테이블 ID 맵"
  value       = module.vpc.private_db_route_table_ids
}

output "nat_gateway_ids" {
  description = "AZ 인덱스로 키된 NAT 게이트웨이 ID 맵"
  value       = module.vpc.nat_gateway_ids
}

# =============================================================================
# VPC 엔드포인트 출력값들 (모듈 기반)
# =============================================================================

output "vpce_security_group_id" {
  description = "VPC 인터페이스 엔드포인트에서 사용하는 보안 그룹 ID"
  value       = module.vpc_endpoints.vpce_security_group_id
}

output "s3_gateway_endpoint_id" {
  description = "S3용 게이트웨이 VPC 엔드포인트 ID"
  value       = module.vpc_endpoints.s3_gateway_endpoint_id
}

output "interface_endpoint_ids" {
  description = "전체 서비스 이름으로 키된 인터페이스 엔드포인트 ID 맵"
  value       = module.vpc_endpoints.interface_endpoint_ids
}

# 개별 서비스 엔드포인트 ID (편의성을 위한 개별 출력)
output "ssm_vpc_endpoint_id" {
  description = "SSM VPC 엔드포인트 ID"
  value       = try(module.vpc_endpoints.interface_endpoint_ids["ssm"], null)
}

output "secretsmanager_vpc_endpoint_id" {
  description = "Secrets Manager VPC 엔드포인트 ID"
  value       = try(module.vpc_endpoints.interface_endpoint_ids["secretsmanager"], null)
}

output "ecr_api_vpc_endpoint_id" {
  description = "ECR API VPC 엔드포인트 ID"
  value       = try(module.vpc_endpoints.interface_endpoint_ids["ecr.api"], null)
}

output "ecr_dkr_vpc_endpoint_id" {
  description = "ECR DKR VPC 엔드포인트 ID"
  value       = try(module.vpc_endpoints.interface_endpoint_ids["ecr.dkr"], null)
}

output "logs_vpc_endpoint_id" {
  description = "CloudWatch Logs VPC 엔드포인트 ID"
  value       = try(module.vpc_endpoints.interface_endpoint_ids["logs"], null)
}

output "xray_vpc_endpoint_id" {
  description = "X-Ray VPC 엔드포인트 ID"
  value       = try(module.vpc_endpoints.interface_endpoint_ids["xray"], null)
}

output "kms_vpc_endpoint_id" {
  description = "KMS VPC 엔드포인트 ID"
  value       = try(module.vpc_endpoints.interface_endpoint_ids["kms"], null)
}

output "monitoring_vpc_endpoint_id" {
  description = "CloudWatch Monitoring VPC 엔드포인트 ID"
  value       = try(module.vpc_endpoints.interface_endpoint_ids["monitoring"], null)
}



