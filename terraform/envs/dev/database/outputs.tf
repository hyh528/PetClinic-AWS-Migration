# Database 레이어 출력 값들 (모듈에서 전달)

output "db_instance_id" {
  description = "RDS 인스턴스 ID"
  value       = module.database.db_instance_id
}

output "db_endpoint" {
  description = "RDS 엔드포인트 주소"
  value       = module.database.db_endpoint
}

output "db_port" {
  description = "RDS 포트"
  value       = module.database.db_port
}

output "db_name" {
  description = "데이터베이스 이름"
  value       = module.database.db_name
}

output "db_subnet_group_name" {
  description = "DB 서브넷 그룹 이름"
  value       = module.database.db_subnet_group_name
}

output "db_instance_arn" {
  description = "RDS 인스턴스 ARN"
  value       = module.database.db_instance_arn
}