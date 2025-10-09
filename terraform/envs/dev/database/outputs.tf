# Database 레이어 출력 값들 (Aurora 클러스터)

output "cluster_id" {
  description = "Aurora 클러스터 ID"
  value       = module.database.cluster_id
}

output "cluster_endpoint" {
  description = "Aurora 클러스터 라이터 엔드포인트 (쓰기 작업용)"
  value       = module.database.cluster_endpoint
}

output "reader_endpoint" {
  description = "Aurora 클러스터 리더 엔드포인트 (읽기 작업용)"
  value       = module.database.reader_endpoint
}

output "cluster_port" {
  description = "Aurora 클러스터 포트"
  value       = module.database.db_port
}

output "database_name" {
  description = "기본 데이터베이스 이름"
  value       = module.database.db_name
}

output "cluster_arn" {
  description = "Aurora 클러스터 ARN"
  value       = module.database.cluster_arn
}

output "writer_instance_id" {
  description = "Writer 인스턴스 ID"
  value       = module.database.writer_instance_id
}

output "reader_instance_id" {
  description = "Reader 인스턴스 ID"
  value       = module.database.reader_instance_id
}

output "db_subnet_group_name" {
  description = "DB 서브넷 그룹 이름"
  value       = module.database.db_subnet_group_name
}
