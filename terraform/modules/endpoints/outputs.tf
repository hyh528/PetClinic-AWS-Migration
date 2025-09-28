output "vpce_security_group_id" {
  description = "VPC 인터페이스 엔드포인트에서 사용하는 보안 그룹 ID"
  value       = aws_security_group.vpce.id
}

output "s3_gateway_endpoint_id" {
  description = "S3용 게이트웨이 VPC 엔드포인트 ID"
  value       = aws_vpc_endpoint.s3.id
}

output "interface_endpoint_ids" {
  description = "전체 서비스 이름으로 키된 인터페이스 엔드포인트 ID 맵"
  value       = { for k, v in aws_vpc_endpoint.interface : k => v.id }
}