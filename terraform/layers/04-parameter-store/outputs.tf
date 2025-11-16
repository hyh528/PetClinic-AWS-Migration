# =============================================================================
# Parameter Store Layer Outputs - 단순화된 출력값
# =============================================================================

# =============================================================================
# 1. 기본 파라미터 정보
# =============================================================================

output "parameter_count" {
  description = "생성된 파라미터 총 개수"
  value       = length(local.basic_parameters) + length(local.database_parameters)
}

output "parameter_prefix" {
  description = "Parameter Store 파라미터 접두사"
  value       = var.parameter_prefix
}

# =============================================================================
# 2. 데이터베이스 연결 정보
# =============================================================================

output "database_connection_ready" {
  description = "데이터베이스 연결 설정 준비 상태"
  value       = local.dependencies_ready
}

output "aurora_endpoint" {
  description = "참조된 Aurora 엔드포인트"
  value       = local.aurora_endpoint
  sensitive   = true
}

# =============================================================================
# 3. 의존성 및 상태 정보
# =============================================================================

output "layer_dependencies" {
  description = "레이어 의존성 상태"
  value = {
    database_layer_ready = local.database_ready
    dependencies_ready   = local.dependencies_ready

    # 참조된 리소스 정보
    aurora_endpoint_available = local.aurora_endpoint != ""
  }
}

# =============================================================================
# 4. Spring Cloud Config 마이그레이션 상태
# =============================================================================

output "migration_summary" {
  description = "Spring Cloud Config 마이그레이션 요약"
  value = {
    config_server_replaced = true
    parameter_store_ready  = true
    environment            = var.shared_config.environment
    parameter_prefix       = var.parameter_prefix
  }
}