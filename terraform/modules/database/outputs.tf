# Database 모듈 출력 값들 (Aurora)

output "cluster_id" {
  description = "Aurora 클러스터 ID"
  value       = aws_rds_cluster.this.id
}

output "cluster_endpoint" {
  description = "Aurora 클러스터 엔드포인트 (Writer)"
  value       = aws_rds_cluster.this.endpoint
}

output "reader_endpoint" {
  description = "Aurora 리더 엔드포인트 (Reader)"
  value       = aws_rds_cluster.this.reader_endpoint
}

output "db_port" {
  description = "데이터베이스 포트"
  value       = aws_rds_cluster.this.port
}

output "db_name" {
  description = "데이터베이스 이름"
  value       = aws_rds_cluster.this.database_name
}

output "db_subnet_group_name" {
  description = "DB 서브넷 그룹 이름"
  value       = aws_db_subnet_group.this.name
}

# RDS 관리 시크릿은 Terraform에서 직접 참조하지 않음
# 애플리케이션에서 시크릿 이름을 계산하여 사용

output "cluster_arn" {
  description = "Aurora 클러스터 ARN"
  value       = aws_rds_cluster.this.arn
}

output "writer_instance_id" {
  description = "Writer 인스턴스 ID"
  value       = aws_rds_cluster_instance.writer.id
}

output "reader_instance_id" {
  description = "Reader 인스턴스 ID"
  value       = aws_rds_cluster_instance.reader.id
}

output "master_username" {
  description = "마스터 사용자 이름"
  value       = aws_rds_cluster.this.master_username
  sensitive   = true
}