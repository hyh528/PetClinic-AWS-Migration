# Database 모듈 출력 값들

output "db_instance_id" {
  description = "RDS 인스턴스 ID"
  value       = aws_db_instance.mysql.id
}

output "db_endpoint" {
  description = "RDS 엔드포인트 주소"
  value       = aws_db_instance.mysql.endpoint
}

output "db_port" {
  description = "RDS 포트"
  value       = aws_db_instance.mysql.port
}

output "db_name" {
  description = "데이터베이스 이름"
  value       = aws_db_instance.mysql.db_name
}

output "db_subnet_group_name" {
  description = "DB 서브넷 그룹 이름"
  value       = aws_db_subnet_group.this.name
}

output "db_instance_arn" {
  description = "RDS 인스턴스 ARN"
  value       = aws_db_instance.mysql.arn
}