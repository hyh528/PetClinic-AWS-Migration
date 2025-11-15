output "vpc_id" {
  description = "VPC 식별자"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "VPC IPv4 CIDR 블록"
  value       = aws_vpc.this.cidr_block
}

output "vpc_ipv6_cidr" {
  description = "VPC IPv6 CIDR 블록 (IPv6 비활성화 시 null)"
  value       = try(aws_vpc.this.ipv6_cidr_block, null)
}

output "internet_gateway_id" {
  description = "인터넷 게이트웨이 ID"
  value       = aws_internet_gateway.this.id
}

output "egress_only_internet_gateway_id" {
  description = "Egress-only 인터넷 게이트웨이 ID (IPv6 비활성화 시 null)"
  value       = var.enable_ipv6 ? aws_egress_only_internet_gateway.this[0].id : null
}

# 서브넷 (인덱스 문자열로 키된 맵: \"0\",\"1\", ...)

output "public_subnet_ids" {
  description = "AZ 인덱스(0,1,...)로 키된 퍼블릭 서브넷 ID 맵"
  value       = { for k, s in aws_subnet.public : k => s.id }
}

output "private_app_subnet_ids" {
  description = "AZ 인덱스(0,1,...)로 키된 프라이빗 앱 서브넷 ID 맵"
  value       = { for k, s in aws_subnet.private_app : k => s.id }
}

output "private_db_subnet_ids" {
  description = "AZ 인덱스(0,1,...)로 키된 프라이빗 DB 서브넷 ID 맵"
  value       = { for k, s in aws_subnet.private_db : k => s.id }
}

# 라우트 테이블

output "public_route_table_id" {
  description = "퍼블릭 라우트 테이블 ID (공유)"
  value       = aws_route_table.public.id
}

output "private_app_route_table_ids" {
  description = "AZ 인덱스로 키된 프라이빗 앱 라우트 테이블 ID 맵"
  value       = { for k, rt in aws_route_table.private_app : k => rt.id }
}

output "private_db_route_table_ids" {
  description = "AZ 인덱스로 키된 프라이빗 DB 라우트 테이블 ID 맵"
  value       = { for k, rt in aws_route_table.private_db : k => rt.id }
}

# NAT & EIP

output "nat_gateway_ids" {
  description = "AZ 인덱스로 키된 NAT 게이트웨이 ID 맵 (비활성화 시 빈 맵)"
  value       = { for k, nat in aws_nat_gateway.this : k => nat.id }
}

output "nat_eip_allocation_ids" {
  description = "AZ 인덱스로 키된 NAT EIP 할당 ID 맵 (비활성화 시 빈 맵)"
  value       = { for k, e in aws_eip.nat : k => e.id }
}

# AZ (에코)

output "availability_zones" {
  description = "사용된 AZ 목록, 서브넷 인덱스와 정렬"
  value       = var.azs
}