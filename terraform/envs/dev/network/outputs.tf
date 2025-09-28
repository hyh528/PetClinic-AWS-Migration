
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

