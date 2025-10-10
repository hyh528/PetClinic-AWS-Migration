# =============================================================================
# Database Layer Outputs - 다른 레이어에서 참조할 데이터베이스 정보
# =============================================================================

# =============================================================================
# 1. 클러스터 기본 정보
# =============================================================================

output "cluster_id" {
  description = "Aurora 클러스터 ID"
  value       = module.aurora_cluster.cluster_id
}

output "cluster_arn" {
  description = "Aurora 클러스터 ARN"
  value       = module.aurora_cluster.cluster_arn
}

output "cluster_endpoint" {
  description = "Aurora 클러스터 Writer 엔드포인트 (쓰기 작업용)"
  value       = module.aurora_cluster.cluster_endpoint
}

output "reader_endpoint" {
  description = "Aurora 클러스터 Reader 엔드포인트 (읽기 작업용)"
  value       = module.aurora_cluster.reader_endpoint
}

output "cluster_port" {
  description = "Aurora 클러스터 포트"
  value       = module.aurora_cluster.db_port
}

# =============================================================================
# 2. 데이터베이스 정보
# =============================================================================

output "database_name" {
  description = "기본 데이터베이스 이름"
  value       = module.aurora_cluster.db_name
}

output "master_username" {
  description = "마스터 사용자 이름"
  value       = module.aurora_cluster.master_username
  sensitive   = true
}

# =============================================================================
# 3. 인스턴스 정보
# =============================================================================

output "writer_instance_id" {
  description = "Writer 인스턴스 ID"
  value       = module.aurora_cluster.writer_instance_id
}

output "reader_instance_id" {
  description = "Reader 인스턴스 ID"
  value       = module.aurora_cluster.reader_instance_id
}

# =============================================================================
# 4. 네트워크 및 보안 정보
# =============================================================================

output "db_subnet_group_name" {
  description = "DB 서브넷 그룹 이름"
  value       = module.aurora_cluster.db_subnet_group_name
}

output "security_group_id" {
  description = "Aurora 클러스터에서 사용하는 보안 그룹 ID"
  value       = local.aurora_security_group_id
}

output "subnet_ids" {
  description = "Aurora 클러스터에서 사용하는 서브넷 ID 목록"
  value       = local.private_db_subnet_ids
}

# =============================================================================
# 5. 애플리케이션 연결 정보
# =============================================================================

output "connection_info" {
  description = "애플리케이션에서 사용할 데이터베이스 연결 정보"
  value = {
    # JDBC 연결 URL
    writer_jdbc_url = "jdbc:mysql://${module.aurora_cluster.cluster_endpoint}:${module.aurora_cluster.db_port}/${module.aurora_cluster.db_name}"
    reader_jdbc_url = "jdbc:mysql://${module.aurora_cluster.reader_endpoint}:${module.aurora_cluster.db_port}/${module.aurora_cluster.db_name}"

    # 개별 연결 정보
    writer_endpoint = module.aurora_cluster.cluster_endpoint
    reader_endpoint = module.aurora_cluster.reader_endpoint
    port            = module.aurora_cluster.db_port
    database_name   = module.aurora_cluster.db_name
    username        = module.aurora_cluster.master_username

    # 보안 정보 (Secrets Manager에서 관리)
    secrets_manager_arn = "${module.aurora_cluster.cluster_arn}:secret:rds-db-credentials/${module.aurora_cluster.master_username}"
  }
  sensitive = true
}

# =============================================================================
# 6. 운영 정보
# =============================================================================

output "backup_info" {
  description = "백업 및 유지보수 정보"
  value = {
    backup_retention_period = var.backup_retention_period
    backup_window           = var.backup_window
    maintenance_window      = var.maintenance_window
    storage_encrypted       = var.storage_encrypted
  }
}

output "monitoring_info" {
  description = "모니터링 설정 정보"
  value = {
    performance_insights_enabled = var.performance_insights_enabled
    monitoring_interval          = var.monitoring_interval
  }
}

# =============================================================================
# 7. 의존성 및 상태 정보
# =============================================================================

output "layer_dependencies" {
  description = "레이어 의존성 상태"
  value = {
    network_layer_ready  = local.network_ready
    security_layer_ready = local.security_ready
    dependencies_ready   = local.dependencies_ready

    # 참조된 리소스 정보
    referenced_subnets = length(local.private_db_subnet_ids)
    security_group_id  = local.aurora_security_group_id
  }
}

# =============================================================================
# 8. 레거시 호환성 (기존 코드와의 호환성을 위해 유지)
# =============================================================================

output "database_summary" {
  description = "데이터베이스 연결 정보 요약 (레거시 호환성)"
  value = {
    cluster_id      = module.aurora_cluster.cluster_id
    writer_endpoint = module.aurora_cluster.cluster_endpoint
    reader_endpoint = module.aurora_cluster.reader_endpoint
    port            = module.aurora_cluster.db_port
    database_name   = module.aurora_cluster.db_name

    # 애플리케이션에서 사용할 연결 정보
    connection_info = {
      writer_url = "jdbc:mysql://${module.aurora_cluster.cluster_endpoint}:${module.aurora_cluster.db_port}/${module.aurora_cluster.db_name}"
      reader_url = "jdbc:mysql://${module.aurora_cluster.reader_endpoint}:${module.aurora_cluster.db_port}/${module.aurora_cluster.db_name}"
    }

    # 의존성 상태
    dependencies = {
      network_ready  = local.network_ready
      security_ready = local.security_ready
    }
  }
  sensitive = true
}
